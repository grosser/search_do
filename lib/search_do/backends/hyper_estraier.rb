#!/usr/bin/env ruby
require 'vendor/estraierpure'
require 'search_do/utils'

module SearchDo
  module Backends
    class HyperEstraier
      SYSTEM_ATTRIBUTES = %w( uri digest cdate mdate adate title author type lang genre size weight misc )

      attr_reader :connection
      attr_accessor :node_name

      DEFAULT_CONFIG = {
        'host' => 'localhost',
        'port' => 1978,
        'user' => 'admin',
        'password' => 'admin',
        'backend' => 'hyper_estraier',
      }.freeze

      # FIXME use URI
      def initialize(ar_class, config = {})
        @ar_class = ar_class
        config = DEFAULT_CONFIG.merge(config)
        self.node_name = calculate_node_name(config)

        @connection = EstraierPure::Node.new
        @connection.set_url("http://#{config['host']}:#{config['port']}/node/#{self.node_name}")
        @connection.set_auth(config['user'], config['password'])
      end

      def index
        cond = EstraierPure::Condition::new
        cond.add_attr("db_id NUMGT 0")
        result = raw_search(cond, 1)
        result ? result.docs : []
      end

      def search_by_db_id(id)
        cond = EstraierPure::Condition::new
        cond.set_options(EstraierPure::Condition::SIMPLE | EstraierPure::Condition::USUAL)
        cond.add_attr("db_id NUMEQ #{id}")

        result = raw_search(cond, 1)
        return nil if result.nil? || result.doc_num.zero?
        result.first_doc
      end

      def count(query, options={})
        cond = build_fulltext_condition(query, options.merge(:count=>true))
        benchmark("  #{@ar_class.to_s} count fulltext, Cond: #{cond.to_s}") do
          r = raw_search(cond, 1);
          r.doc_num rescue 0
        end
      end

      def search_all(query, options = {})
        cond = build_fulltext_condition(query, options)

        benchmark("  #{@ar_class.to_s} fulltext search, Cond: #{cond.to_s}") do
          result = raw_search(cond, 1);
          result ? result.docs : []
        end
      end

      def search_all_ids(query, options ={})
        search_all_ids_and_raw(query,options).map {|row|row[0]}
      end
      
      def search_all_ids_and_raw(query, options ={})
        search_all(query, options).map{|doc| [doc.attr("db_id").to_i,doc] }
      end

      def add_to_index(texts, attrs)
        doc = EstraierPure::Document::new
        texts.reject(&:blank?).each{|t| doc.add_text(textise(t)) }
        attrs.reject{|k,v| v.blank?}.each{|k,v| doc.add_attr(attribute_name(k), textise(v)) }

        log = "  #{@ar_class.name} [##{attrs["db_id"]}] Adding to index"
        benchmark(log){ @connection.put_doc(doc) }
      end

      def remove_from_index(db_id)
        return unless doc = search_by_db_id(db_id)
        log = "  #{@ar_class.name} [##{db_id}] Removing from index"
        benchmark(log){ delete_from_index(doc) }
      end

      def clear_index!
        benchmark("  Deleting all index"){ index.each { |d| delete_from_index(d) } }
      end

      def raw(id)
        condition = build_fulltext_condition
        add_attributes_to "db_id STREQ #{id}", condition
        result = connection.search(condition, 1)
        return unless result and result.doc_num > 0
        result.docs[0]
      end

    private

      def raw_search(cond, num)
        @connection.search(cond, num)
      end

      def textise(obj) # :nodoc:
        case obj
        when Time then obj.iso8601
        when Date, DateTime then obj.to_s # Date#to_s equals iso8601
        else obj.to_s
        end
      end

      def build_fulltext_condition(query='', options = {})
        options = {:limit => 100, :offset => 0}.merge(options)
        # options.assert_valid_keys(VALID_FULLTEXT_OPTIONS)

        cond = EstraierPure::Condition::new
        cond.set_options(EstraierPure::Condition::SIMPLE | EstraierPure::Condition::USUAL)

        cond.set_phrase Utils.cleanup_query(query)

        #add a always-true condition to trigger find all
        add_attributes_to("db_id NUMGT 0",cond) if query.blank?
        add_attributes_to(options[:attributes],cond)
        cond.set_max   options[:limit] unless options[:count]
        cond.set_skip  options[:offset]
        cond.set_order translate_order_to_he(options[:order]) unless options[:order].blank?
        return cond
      end
      
      def add_attributes_to(attributes,condition)
        case attributes
          when String,nil then condition.add_attr attributes unless attributes.blank?
          when Array then
            attributes.reject(&:blank?).each do |attr|
              condition.add_attr attr
            end
          when Hash then
            attributes.each do |attribute,value|
              next if value.blank? or attribute.blank?
              search_type = search_type_for_attribute(attribute)
              attribute = translate_attribute_name_to_he(attribute)
              condition.add_attr "#{attribute} #{search_type} #{value}"
            end
          else raise
        end
      end

      def search_type_for_attribute(attribute)
        column_type_of(attribute) == :numeric ? 'NUMEQ' : 'iSTRINC'
      end

      def translate_order_to_he(order)
        order_parts = order.to_s.downcase.strip.split(' ') 
        return order if order_parts.size > 2
        return order unless a_or_d(order_parts[1])
        
        translated = translate_attribute_name_to_he(order_parts[0])
        sort_word = (column_type_of(order_parts[0])==:numeric) ? 'NUM' : 'STR'
        "#{translated} #{sort_word}#{a_or_d(order_parts[1])}"
      end

      #is the column numeric(numbers/dates) or string(else) ?
      def column_type_of(attribute)
        column = @ar_class.columns_hash[attribute.to_s]
        return :string unless column
        return :numeric if column.number? or [:datetime,:time,:date,:timestamp].include?(column.type)
        return :string
      end
      
      def translate_attribute_name_to_he(name)
        case name.to_s
          when 'updated_at','updated_on' then "@mdate"
          when 'created_at','created_on' then "@cdate"
          when 'id' then "db_id"
          else name
        end
      end

      #pre: string is downcased & stripped
      def a_or_d(order_end)
        case order_end
          when 'asc' then "A"
          when 'desc','',nil then "D"
          else nil
        end
      end

      def delete_from_index(document)
        @connection.out_doc(document.attr('@id'))
      end

      def benchmark(log, &block)
        @ar_class.benchmark(log, &block)
      end

      def calculate_node_name(config)
        node_prefix = config['node_prefix'] || config['node'] || RAILS_ENV
        "#{node_prefix}_#{@ar_class.table_name}"
      end

      def attribute_name(attribute)
        SYSTEM_ATTRIBUTES.include?(attribute.to_s) ? "@#{attribute}" : "#{attribute}"
      end
    end
  end
end

# call after creating namespace SearchDo::Backends::HyperEstraier
require 'search_do/backends/hyper_estraier/estraier_pure_extention'

