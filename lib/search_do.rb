# Copyright (c) 2006 Patrick Lenz
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Thanks: Rick Olson (technoweenie) for his numerous plugins that served
# as an example

require 'search_do/indexer'
require 'search_do/dirty_tracking'
require 'search_do/backends'
require 'vendor/estraierpure'

# Specify this act if you want to provide fulltext search capabilities to your model via Hyper Estraier. This
# assumes a setup and running Hyper Estraier node accessible through the HTTP API provided by the EstraierPure
# Ruby module (which is bundled with this plugin).
#
# The act supplies appropriate hooks to insert, update and remove documents from the index when you update your
# model data, create new objects or remove them from your database. For the initial indexing a convenience
# class method <tt>reindex!</tt> is provided.
#
# Example:
#
#   class Article < ActiveRecord::Base
#     attr_accessor :snippet
#     acts_as_searchable
#   end
#
#   Article.reindex!
#
# As soon as your model data has been indexed you can make use of the <tt>fulltext_search</tt> class method
# to search the index and get back instantiated matches.
#
#   results = Article.fulltext_search('rails')
#   results.size        # => 3
#
#   results.first.class # => Article
#   results.first.body  # => "Ruby on Rails is an open-source web framework"
#
# Connectivity configuration can be either inherited from conventions or setup globally in the Rails
# database configuration file <tt>config/database.yml</tt>.
#
# Example:
#
#   development:
#     adapter: mysql
#     database: rails_development
#     host: localhost
#     user: root
#     password:
#     estraier:
#       host: localhost
#       user: admin
#       password: admin
#       port: 1978
#       node: development
#
# That way you can configure separate connections for each environment. The values shown above represent the
# defaults. If you don't need to change any of these it is safe to not specify the <tt>estraier</tt> hash
# at all.
#
# See SearchDo::ClassMethods#acts_as_searchable for per-model configuration options
#
module SearchDo

  def self.included(base) #:nodoc:
    base.extend ClassMethods
  end

  module ClassMethods
    VALID_FULLTEXT_OPTIONS = [:limit, :offset, :order, :attributes, :raw_matches, :find, :count]

    # == Configuration options
    #
    # * <tt>searchable_fields</tt> - Fields to provide searching and indexing for (default: 'body')
    # * <tt>attributes</tt> - Additional attributes to store in Hyper Estraier with the appropriate method supplying the value
    # * <tt>if_changed</tt> - Extra list of attributes to add to the list of attributes that trigger an index update when changed
    #
    # Examples:
    #
    #   acts_as_searchable :attributes => { :title => nil, :blog => :blog_title }, :searchable_fields => [ :title, :body ]
    #
    # This would store the return value of the <tt>title</tt> method in the <tt>title</tt> attribute and the return value of the
    # <tt>blog_title</tt> method in the <tt>blog</tt> attribute. The contents of the <tt>title</tt> and <tt>body</tt> columns
    # would end up being indexed for searching.
    #
    # == Attribute naming
    #
    # Attributes that match the reserved names of the Hyper Estraier system attributes are mapped automatically. This is something
    # to keep in mind for custom ordering options or additional query constraints in <tt>fulltext_search</tt>
    # For a list of these attributes see <tt>EstraierPure::SYSTEM_ATTRIBUTES</tt> or visit:
    #
    #   http://hyperestraier.sourceforge.net/uguide-en.html#attributes
    #
    # From the example above:
    #
    #   Model.fulltext_search('query', :order => '@title STRA')               # Returns results ordered by title in ascending order
    #   Model.fulltext_search('query', :attributes => 'blog STREQ poocs.net') # Returns results with a blog attribute of 'poocs.net'
    #
    def acts_as_searchable(options = {})
      return if self.included_modules.include?(SearchDo::InstanceMethods)

      cattr_accessor :search_indexer, :search_backend

      self.search_indexer = returning(SearchDo::Indexer.new(self, configurations)) do |idx|
        idx.searchable_fields   = options[:searchable_fields] || [ :body ]
        idx.attributes_to_store = options[:attributes] || {}
        idx.if_changed          = options[:if_changed] || []
      end

      if !options[:ignore_timestamp] && self.record_timestamps
        search_indexer.record_timestamps!
      end

      unless options[:auto_update] == false
        search_indexer.add_callbacks!
      end

      include SearchDo::InstanceMethods
      include SearchDo::DirtyTracking

      connect_backend(configurations)
    end

    # Perform a fulltext search against the Hyper Estraier index.
    #
    # Adds snippet (text that surround the place where the word was found) to results if the model responds to snippet=
    #
    # Options taken:
    # * <tt>limit</tt>       - Maximum number of records to retrieve (default: <tt>100</tt>)
    # * <tt>offset</tt>      - Number of records to skip (default: <tt>0</tt>)
    # * <tt>order</tt>       - Hyper Estraier expression to sort the results (example: <tt>@title STRA</tt>, default: ordering by score)
    # * <tt>attributes</tt>  - String to append to Hyper Estraier search query
    # * <tt>raw_matches</tt> - Returns raw Hyper Estraier documents instead of instantiated AR objects
    # * <tt>find</tt>        - Options to pass on to the <tt>ActiveRecord::Base#find</tt> call
    # * <tt>count</tt>       - Set this to <tt>true</tt> if you're using <tt>fulltext_search</tt> in conjunction with <tt>ActionController::Pagination</tt> to return the number of matches only
    #
    # Examples:
    #
    #   Article.fulltext_search("biscuits AND gravy")
    #   Article.fulltext_search("biscuits AND gravy", :limit => 15, :offset => 14)
    #   Article.fulltext_search("biscuits AND gravy", :attributes => "tag STRINC food")
    #   Article.fulltext_search("biscuits AND gravy", :attributes => {:user_id=>1})
    #   Article.fulltext_search("biscuits AND gravy", :attributes => {:tag=>'food'})
    #   Article.fulltext_search("biscuits AND gravy", :attributes => ["tag STRINC food", "@title STRBW Biscuit"])
    #   Article.fulltext_search("biscuits AND gravy", :order => "created_at DESC")
    #   Article.fulltext_search("biscuits AND gravy", :raw_matches => true)
    #   Article.fulltext_search("biscuits AND gravy", :find => { :order => :title, :include => :comments })
    #
    # Consult the Hyper Estraier documentation on proper query syntax:
    #
    #   http://hyperestraier.sourceforge.net/uguide-en.html#searchcond
    #
    def fulltext_search(query = "", options = {})
      find_options = options[:find] || {}
      [ :limit, :offset ].each { |k| find_options.delete(k) } unless find_options.blank?

      ids_and_raw = matched_ids_and_raw(query, options)
      ids = ids_and_raw.map{|id,raw| id}
      
      results = find_by_ids_scope(ids, find_options)
      add_snippets(results,ids_and_raw) unless query.blank?
      results
    end

    def paginate_by_fulltext_search(query, options={})
      WillPaginate::Collection.create(*wp_parse_options(options)) do |pager|
        #transform acts_as_searchable options to will_paginate options
        page,per_page,total = wp_parse_options(options)
        options[:limit]=per_page
        options[:offset]=(page.to_i-1)*per_page
        options.delete(:page)#acts_as cannot read this...
        options.delete(:per_page)#acts_as cannot read this...
        
        #find results
        pager.replace fulltext_search(query,options)

        #total items
        #replace sets total if it can calculate by them itself
        unless pager.total_entries
          pager.total_entries = count_fulltext(query, :attributes=>options[:attributes]||{})
        end
      end
    end

    def count_fulltext(query, options={})
      search_backend.count(query, options)
    end

    # this methods is NOT compat with original AAS
    #FIXME is see no need for this method
    def find_fulltext(query, options={}, with_mdate_desc_order=true)
      fulltext_option = {}
      fulltext_option[:order] = :updated_at if with_mdate_desc_order
      ids = matched_ids(query, fulltext_option)
      find_by_ids_scope(ids, options)
    end

    #[[1,Raw],[4,Raw],...]
    def matched_ids_and_raw(query = "", options = {})
      search_backend.search_all_ids_and_raw(query, options)
    end
    
    def matched_ids(query = "", options = {})
      matched_ids_and_raw(query,options).map{|id,raw|id}
    end

    def matched_raw(query = "", options = {})
      matched_ids_and_raw(query,options).map{|id,raw|raw}
    end
    alias :raw_matches :matched_raw

    def raw_fulltext_index
      search_backend.index
    end

    # Clear all entries from index
    def clear_index!
      search_backend.clear_index!
    end

    # Peform a full re-index of the model data for this model
    def reindex!
      find(:all).each { |r| r.update_index(true) }
    end

  private
  
    def add_snippets(results,ids_and_raw)
      results.each do |result|
        raw = ids_and_raw.assoc(result.id)[1]
        result.snippet = raw.snippet if result.respond_to?(:snippet=)
        result.html_snippet = snippet_to_html(raw.snippet_a) if result.respond_to?(:html_snippet=)
      end
    end

    def snippet_to_html(snippet)
      snippet.map do |text,highlite|
        text = strip_tags(text)
        highlite ? "<b>#{text}</b>" : text
      end * ''
    end

    def strip_tags(text)
      #TODO better performance?
      require 'action_controller'
      ::ActionController::Base.helpers.strip_tags(text)
    end
  
    def connect_backend(active_record_config) #:nodoc:
      backend_config = active_record_config[RAILS_ENV]['search'] || \
                       active_record_config[RAILS_ENV]['estraier'] || {}
      self.search_backend = Backends.connect(self, backend_config)
    end

    def find_by_ids_scope(ids, options={})
      return [] if ids.blank?
      results = []
      with_scope(:find=>{:conditions=>["#{table_name}.id IN (?)", ids]}) do
        results = find(:all, options)
      end
      apply_ids_order_to(ids,results)
    end
    
    def apply_ids_order_to(ids,results)
      #replace id with found item
      results.each {|item| ids[ids.index(item.id)] = item}
      #remove the unfound
      ids.reject {|item_or_id| item_or_id.is_a?(Fixnum)}
    end
  end

  module InstanceMethods
    # Update index for current instance
    def update_index(force = false)
      return unless (need_update_index? || force)
      remove_from_index
      add_to_index
    end

    def add_to_index #:nodoc:
      search_backend.add_to_index(search_texts, search_attrs)
    end

    def remove_from_index #:nodoc:
      search_backend.remove_from_index(self.id)
    end

    private
    def search_texts
      search_indexer.searchable_fields.map{|f| send(f) }
    end

    def search_attrs
      attrs = { 'db_id' => id.to_s,
                '@uri' => "/#{self.class.to_s}/#{id}" }
      # for STI
      if self.class.descends_from_active_record?
        attrs["type_base"] = self.class.base_class.to_s
      end

      unless (to_stores = search_indexer.attributes_to_store).blank?
        to_stores.each do |attribute, method|
          value = send(method || attribute)
          value = value.xmlschema if value.is_a?(Time)
          attrs[attribute] = value.to_s
        end
      end
      attrs
    end
  end
end

ActiveRecord::Base.send :include, SearchDo