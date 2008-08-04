%w{rubygems active_record test/unit Shoulda}.each { |lib| require(lib) }

def database_name(db='test.db')
  File.join(File.dirname(__FILE__), db)
end

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => database_name
)

File.unlink(database_name) if File.exists?(database_name)

ActiveRecord::Schema.define do
  create_table :dogs, :force => true do |t|
    t.string :name
    t.integer :age
    t.integer :at_vet, :at_foster, :hospice, :adopted
    t.timestamps
  end
  
  create_table :vettings, :force => true do |t|
    t.integer :heartworms, :fixed
    t.timestamps
  end
end

class Dog < ActiveRecord::Base
  has_many :vettings
  
  def rescued?
    !at_vet? && !at_foster? && !hospice? && !adopted?
  end
  
  def vetted?
    at_vet? && !at_foster? && !hospice? && !adopted?
  end
end

class Vetting < ActiveRecord::Base
  belongs_to :dog
end

class TestDog < Test::Unit::TestCase
  
  context "A dog" do
    setup do
      @dog = Dog.new(:name => 'Cooper', :age => 2)
    end
    
    context "that has just been rescued" do
      should "have a name" do
        assert_equal 'Cooper', @dog.name
      end
      
      should "have an age" do
        assert_equal 2, @dog.age
      end
      
      should "be rescued" do
        assert @dog.rescued?
      end
    end
    
    context "that has been vetted" do
      setup do
        @dog.vettings << Vetting.new(:heartworms => false, :fixed => true)
        @dog.at_vet = true
      end
      
      should "have veterinary information" do
        assert_equal 1, @dog.vettings.length
      end
      
      should "be vetted" do
        assert @dog.vetted?
      end
    end
    
    context "that is being fostered" do
      should_eventually "belong to a foster home"
    end
    
    context "that is in hospice" do
      should_eventually "belong to a hospice home"
    end
    
    context "that has been adopted" do
      should_eventually "have adopter information"
    end
    
  end

end