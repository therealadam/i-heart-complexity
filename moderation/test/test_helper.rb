require 'test/unit'
require 'rubygems'
require 'shoulda'
require 'active_record'

$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')

def database_name(db='test.db')
  File.join(File.dirname(__FILE__), db)
end

File.unlink(database_name) if File.exists?(database_name)

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => database_name
)

ActiveRecord::Schema.define do
  
  create_table :users do |t|
    t.string :name
  end
  
  create_table :posts do |t|
    t.string :title, :body
    t.references :user
  end
  
end

require 'moderation'
