%w{rubygems active_record aasm test/unit Shoulda}.each { |l| require(l) }

def database_name(db='test.db')
  File.join(File.dirname(__FILE__), db)
end

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => database_name
)

File.unlink(database_name) if File.exists?(database_name)

ActiveRecord::Schema.define do
  
  create_table :orders do |t|
    t.string :identifier
    t.references :customer
    t.timestamps
  end
  
  create_table :customers do |t|
    t.string :name, :surname
    t.timestamps
  end
  
  create_table :line_items do |t|
    t.integer :cost
    t.references :order
    t.references :product
    t.timestamps
  end
  
  create_table :products do |t|
    t.string :name
  end
end

class Order < ActiveRecord::Base
  belongs_to :customer
  has_many :line_items
end

class Customer < ActiveRecord::Base
  has_many :orders
end

class LineItem < ActiveRecord::Base
  belongs_to :order
end

class TestOrders < Test::Unit::TestCase
  
  context "An order" do
    setup do
      @order = Order.new
    end
    
    should "have a customer" do
      customer = Customer.new(:name => 'Bob', :surname => 'Smith')
      assert_nothing_raised { @order.customer = customer }
    end
    
    should "have one or more line items" do
      assert_nothing_raised do
        @order.line_items = [LineItem.new(:cost => 100), 
                             LineItem.new(:cost => 200)]
      end
    end
    
    should_eventually "move from the initial to payment state"
    should_eventually "move from the payment to fulfillment state"
    should_eventually "move from the fulfillment state to the complete state"
  end
  
end
