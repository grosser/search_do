require File.expand_path("../spec_helper", File.dirname(__FILE__))

describe SearchDo::Backends::HyperEstraier do
  before do
    @backend = SearchDo::Backends::HyperEstraier.new(Story, ActiveRecord::Base.configurations["test"]["estraier"])
  end

  describe "without index" do
    before do
      @backend.connection.should_receive(:search).and_return(nil)
    end

    it "should be empty" do
      @backend.index.should == []
    end
  end

  describe "include nil to indexed text" do
    it "should not raise error" do
      lambda{ 
        @backend.add_to_index(['foo', nil], {})
      }.should_not raise_error
    end
  end

  describe "date searching" do
    before do
      @backend.clear_index!
      @time = Time.local(2008,9,17)
      @backend.add_to_index([@time], 'db_id' => "1", '@uri' => "/Story/1")
    end

    it "should searchable with time in iso format" do
      @backend.count(@time.iso8601).should > 0
    end

    it "is ordered through dates" do
      @backend.add_to_index([], 'db_id' => "1", 'read_at'=>Time.now, '@uri' => "/Story/1")
      @backend.add_to_index([], 'db_id' => "2", 'read_at'=>Time.now+1.day, '@uri' => "/Story/2")
      @backend.add_to_index([], 'db_id' => "3", 'read_at'=>Time.now-1.day, '@uri' => "/Story/3")
      @backend.search_all_ids('',:order=>"read_at ASC").should == [3,1,2]
    end
  end
  
  describe "raw" do
    before do
      @backend.add_to_index([], 'db_id' => "1", '@uri' => "/Story/1")
    end
    
    it "finds a raw document" do
      @backend.raw(1).should_not be_nil
      @backend.raw(1).attr('db_id').should == '1'
    end
  end

  describe :build_fulltext_condition do
    it "does not use limit for counting" do
      @backend.send(:build_fulltext_condition,'',:count=>true).max.should == -1
    end
    
    describe 'parsing attributes' do
      def condition(options)
        @backend.send(:build_fulltext_condition,'something',options)
      end
      
      it 'raises on unknown' do
        lambda{condition(:attributes=>1)}.should raise_error(RuntimeError)
      end
      
      it "removes blanks" do
        condition(:attributes=>['','  ','a']).attrs.should == ['a']
      end
      
      it 'ignores empty' do
        condition(:attributes=>nil).attrs.should == []
        condition(:attributes=>'').attrs.should == []
      end
      
      it "adds a always-true condition when search is blank" do
        @backend.send(:build_fulltext_condition,'  ').attrs.should_not be_blank
      end
      
      it "parses a string" do
        condition(:attributes=>'x y z').attrs.should == ['x y z']
      end
      
      it "parses an array" do
        condition(:attributes=>['a b c','d e f']).attrs.should == ['a b c','d e f']
      end
      
      
      describe 'parsing a hash' do
        before :all do
          Story.columns_hash['popularity'].should be_number
          Story.columns_hash['title'].should be_text
        end

        it "parses a simple hash" do
          condition(:attributes=>{:a=>'b'}).attrs.should == ['a iSTRINC b']
        end
        
        it "parses a blank hash" do
          condition(:attributes=>{:a=>''}).attrs.should == []
        end
        
        it "parses a keyless hash" do
          condition(:attributes=>{''=>'wtf'}).attrs.should == []
        end
        
        it "parses a number column to number search" do
          condition(:attributes=>{'popularity'=>12}).attrs.should == ['popularity NUMEQ 12']
        end
        
        it "parses a string column to string search" do
          condition(:attributes=>{'title'=>12}).attrs.should == ['title iSTRINC 12']
        end
        
        it "translates columns" do
          condition(:attributes=>{'id'=>1}).attrs.should == ['db_id NUMEQ 1']
        end
        
        it "parses a unknown column to string search" do
          condition(:attributes=>{'xxx'=>'x'}).attrs.should == ['xxx iSTRINC x']
        end
        
        it "parses a date or time" do
          pending do
            #raw output: "@mdate" "2008-09-21T09:51:27+02:00"
            raise
          end
        end
      end
    end
    
    describe "translate order" do
      def translated_order(order)
        @backend.send(:build_fulltext_condition,'',:order=>order).order
      end

      it "translates nil to nil" do
        translated_order(nil).should == nil
      end

      it "translates blank to nil" do
        translated_order("").should == nil
      end

      it "translates strings to STRA" do
        translated_order('title ASC').should == 'title STRA'
        translated_order('title asc').should == 'title STRA'
      end

      it "translates strings to STRD" do
        translated_order('title').should == 'title STRD'
        translated_order('title DESC').should == 'title STRD'
        translated_order('title desc').should == 'title STRD'
      end

      it "translates dates to NUMD" do
        translated_order(:written_on).should == "written_on NUMD"
      end
      
      it "translates datetimes to NUM" do
        translated_order("read_at ASC").should == "read_at NUMA"
      end
      
      it "translates numbers to NUMD" do
        translated_order(:popularity).should == "popularity NUMD"
      end
      
      it "translates numbers with asc to NUMA" do
        translated_order("popularity ASC").should == "popularity NUMA"
      end
      
      it "translate non-columns to string" do
        translated_order("paid_at ASC").should == "paid_at STRA"
      end
      
      describe "translating rails-terms" do
        before :all do
          class FakeColumn
            def number?;false;end
            def type;:date;end
          end
          Story.columns_hash["created_on"] = FakeColumn.new
          Story.columns_hash["updated_on"] = FakeColumn.new
        end

        after :all do
          Story.reset_column_information
        end
        
        #symbols and desc <-> DESC only need testing once, to see if order values get normalized
        ['updated_at','updated_on',:updated_at,'updated_at DESC','updated_at desc'].each do |order|
          it "translates #{order}" do
            translated_order(order).should == "@mdate NUMD"
          end
        end
        ['created_at','created_on','created_at DESC'].each do |order|
          it "translates #{order}" do
            translated_order(order).should == "@cdate NUMD"
          end
        end
        ['id','id DESC'].each do |order|
          it "translates #{order}" do
            translated_order(order).should == "db_id NUMD"
          end
        end
        
        it "does not translate strange things" do
          translated_order('id strange').should == 'id strange'
        end
        
        it "does not translate long orders" do
          translated_order('id desc wtf').should == 'id desc wtf'
        end
      end
    end
  end
end