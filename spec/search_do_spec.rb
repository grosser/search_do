require File.expand_path("spec_helper", File.dirname(__FILE__))

require 'digest/sha1'

describe Story, "extended by acts_as_searchable_enhance" do
  it "should respond_to :fulltext_search" do
    Story.should respond_to(:fulltext_search)
  end

  it "should have callbak :update_index" do
    Story.after_update.should include(:update_index)
  end

  it "should have callbak :add_to_index" do
    Story.after_create.should include(:add_to_index)
  end

  describe "separate node by model classname" do
    before(:all) do
      OtherKlass = Class.new(ActiveRecord::Base)
      OtherKlass.class_eval do
        acts_as_searchable :ignore_timestamp => true
      end
    end

    it "OtherKlass.search_backend.node_name.should == 'aas_e_test_other_klasses'" do
      OtherKlass.search_backend.node_name.should == 'aas_e_test_other_klasses'
    end

    it "search_backend.node_name should == 'aas_e_test_stories'" do
      Story.search_backend.node_name.should == 'aas_e_test_stories'
    end
  end

  describe "matched_ids" do
    fixtures :stories
    before do
      @story_ids = Story.find(:all, :limit=>2).map(&:id)

      @mock_results = @story_ids.map{|id| mock("ResultDocument_#{id}", :attr => id) }
      nres = EstraierPure::NodeResult.new(@mock_results, {})
      Story.search_backend.connection.stub!(:search).and_return(nres)
    end

    it "finds all story ids" do
      Story.matched_ids("hoge").should == @story_ids
    end

    it "calls EstraierPure::Node#search()" do
      Story.search_backend.connection.should_receive(:search)
      Story.matched_ids("hoge")
    end
  end

  describe "remove from index" do
    fixtures :stories
    before do
      stories = Story.find(:all, :limit=>2)
      @story = stories.first
      mock_results = stories.map{|s| mock("ResultDocument_#{s.id}", :attr => s.id) }

      nres = EstraierPure::NodeResult.new(mock_results, {})
      Story.search_backend.connection.stub!(:search).and_return(nres)
    end

    it "should call EstraierPure::Node#delete_from_index" do
      Story.search_backend.connection.should_receive(:out_doc)
      @story.remove_from_index
    end
  end

  describe "matched_ids_and_raw => [:id,raw] and find_option=>{:condition => 'id = :id'}" do
    def fake_raw
      mock(:snippet=>'snip')
    end
    
    fixtures :stories
    before do
      stories = Story.find(:all)
      @story = stories.first
      fake_results = stories.map{|story| [story.id,fake_raw]}
      Story.stub!(:matched_ids_and_raw).and_return fake_results
    end

    def fulltext_search
      finder_opt = {:conditions => ["id = ?", @story.id]}
      Story.fulltext_search("hoge", :find => finder_opt)
    end

    it "fulltext_search should find story" do
      fulltext_search.should == [@story]
    end

    it "fulltext_search should call matched_ids_and_raw" do
      Story.should_receive(:matched_ids_and_raw).and_return([@story.id,"Raw"])
      fulltext_search
    end
  end

  describe "new interface Model.find_fulltext(query, options={})" do
    fixtures :stories
    
    before do
      Story.stub!(:matched_ids).and_return([102, 101, 110])
    end

    it "find_fulltext('hoge', :order=>'updated_at DESC') should == [stories(:sanshiro), stories(:neko)]" do
      Story.find_fulltext('hoge', :order=>"updated_at DESC").should == Story.find([102,101]).reverse
    end
  end

  describe "search using real HyperEstraier (End-to-End test)" do
    fixtures :stories
    before(:all) do
      Story.clear_index!
      #Story.delete_all
      Story.create!(:title=>"むかしむかし", :body=>"あるところにおじいさんとおばあさんが")
      Story.reindex!
      # waiting Estraier sync index, adjust 'cachernum' in ${estraier}/_conf if need
      sleep 1
    end

    before(:each) do
      @story = Story.find_by_title("むかしむかし")
    end

    it "finds a indexed object" do
      Story.fulltext_search('むかしむかし').should == [@story]
    end

    it "counts correctly using count_fulltext" do
      Story.count_fulltext('むかしむかし').should == 1
    end
    
    it "finds all object when searching for ''" do
      Story.fulltext_search('').size.should == Story.count
    end

    # asserts HE raw_match order
    it "finds in correct order(descending)" do
      Story.matched_ids('記憶', :order => "@mdate NUMD").should == [101, 102]
    end

    it "finds in correct order(ascending)" do
      Story.matched_ids('記憶', :order => "@mdate NUMA").should == [102, 101]
    end
    
    it "preserves order of found objects" do
      Story.fulltext_search('記憶', :order => "@mdate NUMA").map(&:id).should == [102, 101]
    end
    
    it "preservers order if scope is given" do
      pending
    end
    
    it "has all objects in index" do
      Story.search_backend.index.size.should == Story.count
    end
  end

  describe "partial updating" do
    fixtures :stories
    before do
      @story = Story.find(:first)
      @story.stub!(:record_timestamps).and_return(false)
    end

    it "should update fulltext index when update 'title'" do
      Story.search_backend.should_receive(:add_to_index).once
      @story.title = "new title"
      @story.save
    end

    it "should update fulltext index when update 'popularity'" do
      Story.search_backend.should_not_receive(:add_to_index)
      @story.popularity = 20
      @story.save
    end
  end
end

describe "StoryWithoutAutoUpdate" do
  before(:all) do
    class StoryWithoutAutoUpdate < ActiveRecord::Base
      set_table_name :stories
      acts_as_searchable :searchable_fields=>[:title, :body], :auto_update=>false
    end
  end

  it "should have callbak :update_index" do
    StoryWithoutAutoUpdate.after_update.should_not include(:update_index)
  end

  it "should have callbak :add_to_index" do
    StoryWithoutAutoUpdate.after_create.should_not include(:add_to_index)
  end
end

describe SearchDo::Utils do
  describe "tokenize_query" do
    it "does not convert empty strings to nil" do
      SearchDo::Utils.tokenize_query('').should == ''
    end
    
    it "combines words with AND'" do
      SearchDo::Utils.tokenize_query('ruby vim').should == 'ruby AND vim'
    end

    it %[coverts '"ruby on rails" vim' to 'ruby on rails AND vim'] do
      SearchDo::Utils.tokenize_query('"ruby on rails" vim').should == 'ruby on rails AND vim'
    end

    it %[converts long unicode spaces] do
      SearchDo::Utils.tokenize_query('"ruby on rails"　vim').should == 'ruby on rails AND vim'
    end
  end
end
