require File.expand_path("../spec_helper", File.dirname(__FILE__))

describe :need_update_index? do
  def needs
    @story.send(:need_update_index?)
  end
  
  before do
    @story = Story.new
  end
  
  it "does not need update when object is new" do
    needs.should be_false
  end
  
  it "needs update when column changes" do
    @story.title = "new value"
    needs.should be_true
  end
  
  it "needs update when a indexed non-column changes" do
    pending do
      @story.non_column = "new value"
      needs.should be_true
    end
  end
  
  it "does not need update after changes have been cleared" do
    @story.title = "new value"
    @story.send(:clear_changed_attributes)
    needs.should be_false
  end
end
