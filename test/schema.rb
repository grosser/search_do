ActiveRecord::Schema.define(:version => 0) do
  create_table :articles, :force => true do |t|
    t.column "title", :string
    t.column "body", :string
    t.column "tags", :string
    t.column "created_at", :datetime
    t.column "comments_count", :integer, :default => 0
  end
  
  create_table :comments, :force => true do |t|
    t.column "body", :string
    t.column "article_id", :integer
  end
  
  create_table :notifications, :force => true do |t|
    t.column :body, :string
    t.column :type, :string
  end
end