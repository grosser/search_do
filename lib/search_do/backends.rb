require 'search_do/backends/hyper_estraier'

module SearchDo
  module Backends
    def connect(model_klass, config)
      backend = config['backend'] || "hyper_estraier"

      case backend
      when "hyper_estraier", nil # default
        Backends::HyperEstraier.new(model_klass, config)
      else
        raise NotImplementedError.new("#{backend} backend is not supported")
      end
    end
    module_function :connect
  end
end
