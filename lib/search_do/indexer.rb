require 'set'

module SearchDo
  class Indexer
    attr_reader :searchable_fields, :if_changed, :attributes_to_store
    def initialize(base, configuration)
      @base = base
      @configuration = configuration
    end

    def searchable_fields=(fields)
      expire_observing_fields_cache!
      @searchable_fields = fields
    end

    def if_changed=(fields)
      expire_observing_fields_cache!
      @if_changed = fields
    end

    def attributes_to_store=(attrs)
      expire_observing_fields_cache!
      @attributes_to_store = attrs.stringify_keys
    end

    def observing_fields(update = false)
      expire_observing_fields_cache! if update
      @observing_fields ||=
        Set.new((if_changed + searchable_fields + attributes_to_store.values).map(&:to_s))
    end

    def record_timestamps!
      begin
        detect_col = lambda{|candidate_col| @base.column_names.include?(candidate_col) }
        @attributes_to_store[backend_vocabulary :create_timestamp] =
          %w(created_at created_on).detect(&detect_col)
        @attributes_to_store[backend_vocabulary :update_timestamp] =
          %w(updated_at updated_on).detect(&detect_col)
        expire_observing_fields_cache!
      rescue
        #allow db-operations like schema loading etc to work without this crashing
        puts "Your database is non-existent or in a very bad state -- From:#{__FILE__}:#{__LINE__}"
      end
    end

    def add_callbacks!
      @base.after_update(:update_index)
      @base.after_create(:add_to_index)
      @base.after_destroy(:remove_from_index)
      @base.after_save(:clear_changed_attributes)
    end

    private
    def expire_observing_fields_cache!
      @observing_fields = nil
    end
    
    # TODO
    def backend_vocabulary(type)
      { :update_timestamp => 'mdate',
        :create_timestamp => 'cdate',
      }[type]
    end
  end
end
