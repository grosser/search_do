class Article < ActiveRecord::Base
  acts_as_searchable :searchable_fields => [ :title, :body ], 
    :attributes => { :title => nil, :custom_attribute => :tags, :cdate => :created_at, :comments_count => nil }
  has_many :comments
end