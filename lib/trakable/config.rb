# frozen_string_literal: true

module Trakable
  # Stores global configuration for Trakable gem.
  # Use Trakable.configure to set options.
  class Configuration
    attr_accessor :enabled,
                  :ignored_attrs

    def initialize
      @enabled = true
      @ignored_attrs = %w[created_at updated_at id]
    end
  end
end
