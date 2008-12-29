require File.expand_path("spec_helper", File.dirname(__FILE__))
require 'search_do/indexer'

describe SearchDo::Indexer,"new(AR[created_at updated_at]) / and set some attrs" do
  before do
    @ar_klass = mock("ar_klass")
    @ar_klass.stub!(:column_names).and_return(%[created_at updated_at])

    @indexer = SearchDo::Indexer.new(@ar_klass, {})
    @indexer.searchable_fields = %w[title body]
    @indexer.attributes_to_store = {:user_id => :user_id}
    @indexer.if_changed = %w[popularity]
  end

  it "#searchable_fields should == %w[title body]" do
    @indexer.searchable_fields.should == %w[title body]
  end

  it "#attributes_to_store['user_id'].should == :user_id" do
    @indexer.attributes_to_store['user_id'].should == :user_id
  end

  it "#observing_fields.should == Set.new(%w[title body user_id popularity])" do
    @indexer.observing_fields.should == Set.new(%w[title body user_id popularity])
  end

  describe "call '.record_timestamps!'" do
    before do
      @indexer.record_timestamps!
    end

    it "#attributes_to_store['cdate'] should == 'created_at'" do
      @indexer.attributes_to_store['cdate'].should == 'created_at'
    end

    it "#attributes_to_store['mdate'] should == 'updated_at'" do
      @indexer.attributes_to_store['mdate'].should == 'updated_at'
    end

    it "#observing_fields.should include 'updated_at' and 'created_at'" do
      @indexer.observing_fields.should include('created_at')
      @indexer.observing_fields.should include('updated_at')
    end
  end

  describe "#add_callbacks!() " do
    before do
      @ar_klass.should_receive(:after_update).with(:update_index)
      @ar_klass.should_receive(:after_create).with(:add_to_index)
      @ar_klass.should_receive(:after_save).with(:clear_changed_attributes)
      @ar_klass.should_receive(:after_destroy).with(:remove_from_index)
    end

    it "adds appropriate callbacks" do
      @indexer.add_callbacks!
    end
  end
end

