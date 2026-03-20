# frozen_string_literal: true

module Trakable
  # Stores global configuration for Trakable gem.
  # Use Trakable.configure to set options.
  class Configuration
    attr_accessor :enabled, :whodunnit_method

    def initialize
      @enabled = true
      @ignored_attrs = %w[created_at updated_at id]
      @whodunnit_method = :current_user
    end

    # Ensure ignored_attrs are always stored as strings for performance
    def ignored_attrs=(attrs)
      @ignored_attrs = Array(attrs).map(&:to_s)
    end

    attr_reader :ignored_attrs
  end
end
