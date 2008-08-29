%w{rubygems active_record test/unit Shoulda}.each { |l| require(l) }

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
    t.string :customer_name
    t.string :customer_address
    t.float :amount
  end
  
  create_table :line_items do |t|
    t.references :order
    t.references :product
  end
  
  create_table :products do |t|
    t.string :name
    t.float :price
  end
  
end

class Order < ActiveRecord::Base
  has_many :line_items
  has_many :products, :through => :line_items
end

class Product < ActiveRecord::Base
end

class OrderTest < Test::Unit::TestCase
  
  def setup
    @order = Order.create(:customer_name => 'Ulysses Arthur', 
                          :customer_address => '123 Example Rd.', 
                          :amount => 12.34)
  end
  
  should "find orders by customer name" do
    assert_equal @order, 
                 Order.find_by_customer_name(
                  'Ulysses Arthur')
  end
  
  should "add some products and calculate amount" do
    products = [Product.create(:name => 'Gizmo', 
                               :price => '1.23'),
                Product.create(:name => 'Frobber', 
                               :price => '2.34')]
    @order.products = products
    assert_equal @order.amount, 3.57
  end
  
end