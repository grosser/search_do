# ---- requirements
$KCODE = 'u' #activate regex unicode
require 'spec'
$LOAD_PATH << File.expand_path("../lib", File.dirname(__FILE__))

require 'active_record'

require File.expand_path("../init", File.dirname(__FILE__))

module Rails
  def self.env
    'test'
  end
end

ActiveRecord::Base.configurations = {"test" => {
  :adapter => "sqlite3",
  :database => ":memory:",
  :estraier => {:host=> "localhost", :node=>"aas_e_test", :user=>"admin", :password=>"admin"}
}.with_indifferent_access}

ActiveRecord::Base.logger = Logger.new(File.directory?("log") ? "log/#{RAILS_ENV}.log" : "/dev/null")
ActiveRecord::Base.establish_connection(:test)

load File.expand_path("setup_test_model.rb", File.dirname(__FILE__))


# ---- fixtures
Spec::Example::ExampleGroupMethods.module_eval do
  def fixtures(*tables)
    dir = File.expand_path("fixtures", File.dirname(__FILE__))
    tables.each{|table| Fixtures.create_fixtures(dir, table.to_s) }
  end
end

