class Notification < ActiveRecord::Base
  acts_as_searchable
end

class CommentNotification < Notification
end