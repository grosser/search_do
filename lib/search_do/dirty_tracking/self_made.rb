
module SearchDo
  module DirtyTracking
    module SelfMade
      def self.included(base)
        base.class_eval do
          attr_accessor :changed_attributes

          search_indexer.observing_fields.each do |attr_name|
            define_method("#{attr_name}=") do |value|
              write_changed_attribute attr_name, value
            end
          end
        end
      end

      # If called with no parameters, gets whether the current model has changed and needs to updated in the index.
      # If called with a single parameter, gets whether the parameter has changed.
      def need_update_index?(attr_name = nil)
        changed_attributes and (attr_name.nil? ?
          (not changed_attributes.length.zero?) : (changed_attributes.include?(attr_name.to_s)) )
      end

      private
      def clear_changed_attributes #:nodoc:
        self.changed_attributes = []
      end

      def write_changed_attribute(attr_name, attr_value) #:nodoc:
        (self.changed_attributes ||= []) << attr_name.to_s unless self.need_update_index?(attr_name) or self.send(attr_name) == attr_value
        write_attribute(attr_name.to_s, attr_value)
      end
    end
  end
end

