# frozen_string_literal: true

require_relative 'trakable/version'

# Trakable provides audit logging and version tracking for ActiveRecord models.
# It offers polymorphic whodunnit tracking, changesets, and built-in retention.
module Trakable
  @configuration = nil

  class << self
    # Returns the global configuration.
    # Eagerly initialized after require to eliminate thread-safety race.
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def enabled?
      configuration.enabled
    end

    def with_user(user, &)
      Context.with_user(user, &)
    end

    def with_tracking(&)
      Context.with_tracking(&)
    end

    def without_tracking(&)
      Context.without_tracking(&)
    end
  end
end

require_relative 'trakable/cleanup'
require_relative 'trakable/config'
require_relative 'trakable/context'
Trakable.autoload :Controller, 'trakable/controller'
require_relative 'trakable/model'
require_relative 'trakable/revertable'
require_relative 'trakable/trak'
require_relative 'trakable/tracker'

require_relative 'trakable/railtie' if defined?(Rails::Railtie)

# Eager-initialize configuration to eliminate thread-safety race on first access
Trakable.configuration
