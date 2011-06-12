require 'search_do/dirty_tracking/self_made'
require 'search_do/dirty_tracking/bridge'

module SearchDo
  module DirtyTracking
    def self.included(base)
      mod = if defined?(ActiveModel::Dirty) && base.included_modules.include?(ActiveModel::Dirty)
              DirtyTracking::Bridge
            else
              DirtyTracking::SelfMade
            end
      base.send(:include, mod)
    end
  end
end
