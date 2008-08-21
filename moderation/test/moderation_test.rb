require 'test_helper'

class ModerationTest < Test::Unit::TestCase
  context "A new user" do
    
    setup do
      @user = User.create(:name => 'Abraham Lincoln')
    end
    
    context "before posting to a forum" do
      
      setup do
        @user.posts.create(:title => 'On the proper care of a generous beard',
                           :body => 'It is harder than running the country')
      end
      
      should "create a new post" do
        assert_equal 1, Post.count
      end
      
      should_eventually "create a moderation queue entry" do
        assert_equal 1, ModerationQueue.length
      end
      
    end
    
    context "after posting to a forum" do
      should_eventually "become a regular user" do
        
      end
      
      should_eventually "approve the post" do
        
      end
    end
    
  end
  
  context "A regular user posts to a forum" do
    
    should_eventually "not add an entry to the moderation queue" do
      
    end
    
    should_eventually "create a new post" do
      
    end
    
  end
  
  context "A staff user" do
    
    context "creating a new post" do
      
      should_eventually "create a new post" do
        
      end
      
      should_eventually "create an entry in the moderation queue" do
        
      end
      
    end
    
    context "editing a post" do
      
      should_eventually "create an entry in the moderation queue" do
        
      end
    end
  end
  
end
