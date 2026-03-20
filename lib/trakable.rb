# frozen_string_literal: true

require_relative 'trakable/version'

# Trakable provides audit logging and version tracking for ActiveRecord models.
# It offers polymorphic whodunnit tracking, changesets, and built-in retention.
module Trakable
  class << self
    # Returns the global configuration.
    # Thread-safe after initial access (configure at app boot).
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

require_relative 'trakable/config'
require_relative 'trakable/context'
require_relative 'trakable/model'
require_relative 'trakable/trak'
require_relative 'trakable/tracker'

require_relative 'trakable/railtie' if defined?(Rails::Railtie)
