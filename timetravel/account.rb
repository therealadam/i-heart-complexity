%w{rubygems active_record acts_as_versioned 
   test/unit Shoulda}.each { |l| require(l) }

def database_name(db='test.db')
  File.join(File.dirname(__FILE__), db)
end

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => database_name
)

File.unlink(database_name) if File.exists?(database_name)

ActiveRecord::Schema.define do
  create_table :accounts, :force => true do |t|
    t.string :name, :street, :city, :state, :zip
    t.integer :version
  end
  
  create_table :account_versions, :force => true do |t|
    t.string :name, :street, :city, :state, :zip
    t.integer :version, :account_id
  end
  
  # If you already have an Account class laying around, you can do this:
  # Account.create_versioned_table
end

class Account < ActiveRecord::Base
  acts_as_versioned
end

class TestAccount < Test::Unit::TestCase
  context "An account" do
    
    setup do
      @act = Account.create(:name => 'Avi Kagan', 
                            :street => '123 Main', 
                            :city => 'Everytown', 
                            :state => 'NY', 
                            :zip => '22000')
    end
    
    should "save one revision" do
      assert_equal 1, @act.versions.length
    end
    
    should "save the current revision and store the old one" do
      @act.street = '321 Elm'
      @act.city = 'Sometown'
      @act.save
      
      assert_equal 2, @act.versions.length
    end
    
    should "access old revisions" do
      @act.street = '321 Elm'
      @act.city = 'Sometown'
      @act.save
      
      assert_equal '123 Main', @act.previous.street
    end
    
  end
end
