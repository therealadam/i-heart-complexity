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
  
  create_table :customers, :force => true do |t|
    t.string :name
    t.string :currency
    t.string :address
  end
  
  create_table :orders, :force => true do |t|
    t.references :customer
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

class Customer < ActiveRecord::Base
  has_many :orders
  
  validates_presence_of :name
  validates_presence_of :currency
end

class Order < ActiveRecord::Base
  belongs_to :customer
  has_many :line_items
  has_many :products, :through => :line_items
  
  validates_presence_of :customer_name
  
  def amount
    # Note that products.inject(0) 
    # won't work because its _not_ Money.
    sum = products.inject(0.to_money) do |sum, p| 
      sum += p.price
    end
    
    if sum.currency == customer.currency
      sum
    else
      sum.exchange_to(customer.currency)
    end
  end
  
end

class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
end

class Product < ActiveRecord::Base
  validates_presence_of :name
  composed_of :price, 
              :class_name => 'Money', 
              :mapping => [%w(cents cents), 
                           %w(currency currency)]
  
  validate :price_greater_than_zero
  
  def price_greater_than_zero
    unless cents > 0
      errors.add('cents', 
                 'cannot be less than zero') 
    end
  end
end

class TestCustomer < Test::Unit::TestCase
  should "require a customer name" do
    assert !Customer.new(:currency => 'USD').valid?
  end
  
  should "require a currency" do
    assert !Customer.new(:name => 'Alexander Whammy').valid?
  end
end

class TestOrder < Test::Unit::TestCase
  
  def setup
    setup_exchanges!
    @customer = Customer.new(:name => 'Grover Lewis', :currency => 'USD')
    @order = Order.new(:customer => @customer)
  end
  
  should "require a customer" do
    assert !Order.new.valid?
  end
  
  context "An order with no line items" do
    setup do
      @order = Order.new(:customer => @customer)
    end
    
    should "have zero price" do
      assert_equal Money.us_dollar(0), @order.amount
    end
  end
  
  context "An order with one line item" do
    
    setup do
      @product = Product.create(:name => 'frobulator', :price => Money.us_dollar(10))
      @order.products << @product
    end
    
    should "have the same amount as the price of its product" do
      assert_equal @product.price, @order.amount
    end
    
  end
  
  context "An order with multiple line items" do
    
    setup do
      @frobulator = Product.create(:name => 'Frobulator', :price => Money.us_dollar(10))
      @grokulator = Product.create(:name => 'Grokulator', :price => Money.us_dollar(100))
      
      @order = Order.new(:customer => @customer)
      @order.products = [@frobulator, @grokulator]
    end
    
    should 'sum the products in the order' do
      assert_equal Money.new(110), @order.amount
    end
    
  end
  
  context "a multi-national order" do
    
    setup do
      @frobulator = Product.create(
        :name => 'Frobulator (US)', 
        :price => Money.us_dollar(10))
      @grokulator = Product.create(
        :name => 'Grokulator (EU)', 
        :price => Money.euro(100))
      
      @order.products = [@frobulator, @grokulator]
    end
    
    should "apply an exchange rate and present the amount in the customer's rate" do
      assert_equal Money.new(157, 'USD'), @order.amount
    end
    
  end
  
  def setup_exchanges!
    Money.bank = VariableExchangeBank.new
    Money.bank.add_rate('USD', 'EUR', 0.67648)
    Money.bank.add_rate('EUR', 'USD', 1.47823)    
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

# Add a coupon-code thing or maybe some arbitrary way of splitting up orders?