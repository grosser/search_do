class Comment < ActiveRecord::Base
  acts_as_searchable :if_changed => [ :article_id ]
  belongs_to :article, :counter_cache => true
end