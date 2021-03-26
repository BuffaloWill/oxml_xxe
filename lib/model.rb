require 'rubygems'
require 'data_mapper'
require 'digest/sha1'
require 'dm-migrations'

# Initialize the Master DB
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/master.db")


class Oxfile
    include DataMapper::Resource

    property :id, Serial
    property :filename, String, :length => 400
    property :location, String, :length => 400
    property :desc, String, :length => 500
    property :type, String, :length => 15

end

DataMapper.finalize

# any differences between the data store and the data model should be fixed by this
#   As discussed in http://datamapper.org/why.html it is limited. Hopefully we never create conflicts.
DataMapper.auto_upgrade!
