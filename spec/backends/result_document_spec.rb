require File.expand_path("../spec_helper", File.dirname(__FILE__))
require 'search_do/backends/hyper_estraier/estraier_pure_extention'


describe EstraierPure::ResultDocument do
  describe :snippet do
    before do
      #result of a search for "i am so blue"
      snip = "...i\ti\n \nam\tam\n \nso\tso\n \nblue\tblue\n test\ni\ti\nng makes me happy\n\n"
      @res = EstraierPure::ResultDocument.new('',{},snip,'')
    end

    it "returns a snippets" do
      @res.snippets.should_not be_nil
    end

    it "transform the snippet to a array of lines" do
      @res.snippets.size.should == 10
    end

    it "highlights the found words" do
      #                                     i    ' '   am   ' '   so   ' '   blue   ' test'  i    ng makes...
      @res.snippets.map{|x|x[1]}.should == [true,false,true,false,true,false,true,  false,   true,false]
    end
  end
end