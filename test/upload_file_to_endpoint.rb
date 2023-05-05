require 'rest-client'

file_path = ARGV[0]
if !file_path
  puts "Please provide a file path as a command line argument."
  exit
end

file = File.new(file_path)

response = RestClient.post('http://localhost:5000/', :file => file)
puts response