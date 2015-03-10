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
