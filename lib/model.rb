require 'sequel'

DB = Sequel.sqlite("#{Dir.pwd}/db/master.db")

class Oxfile < Sequel::Model(:oxfiles)
    set_columns :filename
    set_columns :id
    set_columns :location
    set_columns :desc
    set_columns :type
    set_columns :created_at
end

