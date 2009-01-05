# this is a person indexed by hyperestraier
# it should have name/city/country:string about:text online:boolean
class Person < ActiveRecord::Base
  acts_as_searchable(
    :ignore_timestamp=>true, #do not add timestamps to search_backend
    :searchable_fields => [:name,:website,:city,:about],
    :attributes => {"@title"=>:name,:name=>nil,:city=>nil,:country=>nil}#attribute results
    #add @title for higher search weight on this attribute
  )
  attr_accessor :html_snippet #so we get nice html snippets for our search results...

  #customize the length/widths of the fetched snippets
  search_backend.connection.set_snippet_width(150,20,20)#total,beginning(>0!),around

  #only index a person when it is online
  def add_to_index_with_online_check
    add_to_index_without_online_check if online?
  end
  alias_method_chain :add_to_index, :online_check
end
