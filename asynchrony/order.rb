%w{rubygems test/unit shoulda active_record money acts_as_versioned aasm}.each { |lib| require(lib) }

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
  
  create_table :moderations, :force => true do |t|
    t.references :product
    t.string :aasm_state, :null => false
    t.integer :version
    t.timestamps
  end
  
  create_table :products, :force => true do |t|
    t.string :name
    t.text :description
    t.integer :cents, :default => 0
    t.string :currency, :default => 'USD'
    t.integer :version, :null => false
    t.integer :display_version, :default => 0
  end
  
  class Product < ActiveRecord::Base
    acts_as_versioned
  end
  
  Product.create_versioned_table
  
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
    # Note that products.inject(0) won't work because its _not_ Money.
    sum = products.inject(0.to_money) do |sum, product| 
      sum += product.price
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
  acts_as_versioned
  
  has_many :moderations
  
  after_create :create_moderation_entry
  
  validates_presence_of :name
  composed_of :price, :class_name => 'Money', :mapping => [%w(cents cents), %w(currency currency)]
  
  validate :price_greater_than_zero
  
  def price_greater_than_zero
    errors.add('cents', 'cannot be less than zero') unless cents > 0
  end
  
  def display?
    display_version > 0
  end
  
  def current_moderation
    moderations.last
  end
  
  private
    
    def create_moderation_entry
      moderations.create!(:version => version)
    end
  
end

class Moderation < ActiveRecord::Base
  belongs_to :product
  
  include AASM
  
  aasm_initial_state :pending
  
  aasm_state :pending
  aasm_state :approved
  aasm_state :rejected
  
  aasm_event :approve do
    transitions :from => :pending,
                :to => :approved,
                :on_transition => :update_product_display_version
  end
  
  private
  
    def update_product_display_version
      product.display_version = version
      product.save!
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
      @frobulator = Product.create(:name => 'Frobulator (US)', :price => Money.us_dollar(10))
      @grokulator = Product.create(:name => 'Grokulator (EU)', :price => Money.euro(100))
      
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
  
  should "default display_version to 0" do
    assert_equal 0, Product.new.display_version
  end
  
  should "only display if display_version is greater than 0" do
    assert !Product.new.display?
  end
  
  context "A versioned product" do
    
    setup do
      @product = Product.create(
        :name => 'iPhone', 
        :description => 'The phone with web apps!', 
        :price => Money.new(599.99, 'USD'))
    end
    
    should "save the current version of itself" do
      assert_equal 1, @product.versions.length
    end
    
    should "save the previous version of itself" do
      @product.price = Money.new(499.99, 'USD')
      @product.save!
      
      assert_equal 2, @product.versions.length
    end
    
    should 'access data on previous versions of itself' do
      @product.description = 'The phone with native apps!'
      @product.save!
      
      previous_version = @product.versions.latest.previous
      assert_equal 'The phone with web apps!', 
                   previous_version.description
    end
    
    should "provide an accessor for the current moderation" do
      assert_equal @product.moderations.first, @product.current_moderation
    end
    
  end
  
end

class TestModeration < Test::Unit::TestCase
  
  context 'A moderation for a new product' do
    
    setup do
      @product = Product.create!(
        :name => 'Boeing 777-200',
        :description => 'The wide-body with tons of leg room!',
        :price => Money.new(10_000_000_000, 'USD'))
    end
    
    should 'create a new moderation entry' do
      assert_equal 1, Moderation.count
    end
    
    should 'have a pending moderation' do
      assert @product.current_moderation.pending?
    end
    
    should 'track the product version' do
      assert_equal 1, @product.current_moderation.version
    end
    
    should 'not display' do
      assert !@product.display?
    end
    
    context "that is approved" do
      
      setup do
        @product.current_moderation.approve!
      end
      
      should 'move to approved status' do
        assert @product.current_moderation.approved?
      end
      
      should 'update the display version for the product' do
        # PWNED by no identity map
        assert_equal @product.current_moderation.version, 
                     Product.find(@product.id).display_version
      end
      
    end
    
  end
  
  context 'Approving a product' do
    
    should_eventually 'move the moderation entry off the queue'
    
  end
  
end
