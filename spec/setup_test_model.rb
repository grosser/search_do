require 'rubygems'
require 'active_record'
require 'active_record/fixtures'

#activate will_paginate for models
require 'will_paginate'
WillPaginate.enable_activerecord

#create model table
ActiveRecord::Schema.define(:version => 1) do
  create_table "stories" do |t|
    t.date     "written_on"
    t.datetime "read_at"
    t.string   "title"
    t.text     "body"
    t.integer  "popularity", :default =>0
    t.timestamps
  end
end

#create model
class Story < ActiveRecord::Base
  attr_accessor :snippet
  acts_as_searchable :searchable_fields=>[:title, :body],:attributes=>{:non_column=>nil,:body=>nil}
  
  def non_column
    @non_column
  end
  
  def non_column=(val)
    @non_column=val
  end
end

#create node
require File.expand_path("../lib/estraier_admin", File.dirname(__FILE__))
admin = EstraierAdmin.new(ActiveRecord::Base.configurations["test"][:estraier])
admin.create_node(Story.search_backend.node_name)