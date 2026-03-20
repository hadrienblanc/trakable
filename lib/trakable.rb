# frozen_string_literal: true

require_relative 'trakable/version'

# Trakable provides audit logging and version tracking for ActiveRecord models.
# It offers polymorphic whodunnit tracking, changesets, and built-in retention.
module Trakable
  class Error < StandardError; end

  class << self
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
