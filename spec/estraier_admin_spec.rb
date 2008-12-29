require File.expand_path("../lib/estraier_admin", File.dirname(__FILE__))

describe EstraierAdmin do 
  before do
    @admin = EstraierAdmin.new(:user=>"hoge",:password=>"foo")
  end

  it "@config[:user] should == 'hoge'" do
    @admin.instance_eval{@config}[:user].should == 'hoge'
  end

  it "@config[:password] should == 'foo'" do
    @admin.instance_eval{@config}[:password].should == 'foo'
  end

  it "should receive :request_or_raise, with {:name=>'piyo', :label=>'piyo', :action=>8} when create_node()" do
    @admin.should_receive(:request_or_raise).with(:name=>'piyo', :label=>'piyo', :action=>8)
    @admin.create_node('piyo')
  end

  it "should receive :request_or_raise, with {:name=>'piyo', :action=>9, :sure=>1} when delete_node()" do
    @admin.should_receive(:request_or_raise).with(:name=>'piyo', :action=>9, :sure=>1)
    @admin.delete_node('piyo')
  end
end

