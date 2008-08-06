%w{rubygems test/unit Shoulda active_record aasm}.each { |lib| require(lib) }

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
    t.string :aasm_state
    t.timestamps
  end
  
  create_table :vettings, :force => true do |t|
    t.integer :heartworms, :fixed
    t.timestamps
  end
  
  create_table :people, :force => true do |t|
    t.string :name
    t.string :type
    t.timestamps
  end
  
end

class Dog < ActiveRecord::Base
  
  has_many :vettings
  belongs_to :foster_parent
  belongs_to :hospice_provider
  has_one :adoptive_parent
  
  include AASM
  
  aasm_initial_state :sheltered
  
  aasm_state :sheltered
  aasm_state :rescued
  # aasm_state :vetted
  # aasm_state :fostered
  # aasm_state :hospiced
  # aasm_state :adopted
  
  aasm_event :rescue do
    transitions :to => :rescued, :from => [:sheltered]
  end

end

class Vetting < ActiveRecord::Base
  belongs_to :dog
end

class Person < ActiveRecord::Base
end

class FosterParent < Person
  has_many :dogs
end

class HospiceProvider < Person
  has_many :dogs
end

class AdoptiveParent < Person
  has_many :dogs
end

class TestDog < Test::Unit::TestCase
  
  context "A dog" do
    setup do
      @dog = Dog.new(:name => 'Cooper', :age => 2)
      @dog.rescue
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
      
      should_eventually "have veterinary information" do
        assert_equal 1, @dog.vettings.length
      end
      
      should_eventually "be vetted" do
        assert @dog.vetted?
      end
      
    end
    
    context "that is being fostered" do
      
      setup do
        @dog.at_foster = true
        @dog.foster_parent = FosterParent.new(:name => 'Adam')
      end
      
      should_eventually "belong to a foster home" do
        assert_not_nil @dog.foster_parent
      end
      
      should_eventually "be at a foster home" do
        assert @dog.at_foster?
      end
      
    end
    
    context "that is in hospice" do
      
      setup do
        @dog.at_hospice = true
        @dog.hospice_provider = HospiceProvider.new(:name => 'Maggie')
      end
      
      should_eventually "belong to a hospice home" do
        assert_not_nil @dog.hospice_provider
      end
      
      should_eventually "be at a hospice home" do
        assert @dog.at_hospice?
      end
      
    end
    
    context "that has been adopted" do
      
      setup do
        @dog.at_forever_home = true
        @dog.adoptive_parent = AdoptiveParent.new(:name => 'Marcel')
      end
      
      should_eventually "have adopter information" do
        assert_not_nil @dog.adoptive_parent
      end
      
      should_eventually "be adopted" do
        assert @dog.adopted?
      end
    end
    
  end

end