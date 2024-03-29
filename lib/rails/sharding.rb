require 'rails'

require 'rails/sharding/version'
require 'rails/sharding/core'
require 'generators/scaffold_generator'

require 'rails/sharding/railtie' if defined?(Rails::Railtie)

module Rails
  module Sharding
    # delegates all methods to Core, to shorten method calls
    def self.method_missing(method_sym, *arguments, &block)
      Core.send(method_sym, *arguments, &block)
    end
  end
end
