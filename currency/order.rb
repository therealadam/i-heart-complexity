%w{rubygems test/unit shoulda active_record money}.each { |lib| require(lib) }

def database_name(db='test.db')
  File.join(File.dirname(__FILE__), db)
end

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => database_name
)

File.unlink(database_name) if File.exists?(database_name)

ActiveRecord::Schema.define do
  
  create_table :orders, :force => true do |t|
    t.string :customer_name
    t.integer :cents, :default => 0
    t.string :currency, :default => 'USD'
  end
  
  create_table :line_items, :force => true do |t|
    t.references :product
    t.references :order
    t.timestamps
  end
  
  create_table :products, :force => true do |t|
    t.string :name
    t.integer :cents, :default => 0
    t.string :currency, :default => 'USD'
  end
end

class Order < ActiveRecord::Base
  has_many :line_items
  composed_of :amount, :class_name => 'Money', :mapping => [%w(cents cents), %w(currency currency)]
  
  validates_presence_of :customer_name
end

class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
end

class Product < ActiveRecord::Base
  validates_presence_of :name
  composed_of :price, :class_name => 'Money', :mapping => [%w(cents cents), %w(currency currency)]
  
  validate :price_greater_than_zero
  
  def price_greater_than_zero
    errors.add('cents', 'cannot be less than zero') unless cents > 0
  end
end

class TestOrder < Test::Unit::TestCase
  should "require customer name" do
    assert !Order.new.valid?
  end
  
  context "An order with no line items" do
    setup do
      @order = Order.new(:customer_name => 'Grover Lewis')
    end
    
    should "have zero price" do
      assert_equal @order.amount, Money.us_dollar(0)
    end
  end
end

class TestProduct < Test::Unit::TestCase
  should "have a name" do
    assert !Product.new(:cents => 100, :currency => 'EUR').valid?
  end
  
  should "have a price" do
    assert !Product.new(:name => 'Frobulator').valid?
  end
end
