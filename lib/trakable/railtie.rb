# frozen_string_literal: true

module Trakable
  class Railtie < ::Rails::Railtie
    # Register the install generator
    generators do
      require 'generators/trakable/install_generator'
    end

    # Configure default settings for Rails
    initializer 'trakable.configure' do |app|
      # Allow configuration via Rails config
      # In config/application.rb or config/environments/*.rb:
      #   config.trakable.enabled = true
      #   config.trakable.ignored_attrs = %w[created_at updated_at id]
      if app.config.respond_to?(:trakable)
        Trakable.configure do |config|
          config.enabled = app.config.trakable.enabled if app.config.trakable.respond_to?(:enabled)
          config.ignored_attrs = app.config.trakable.ignored_attrs if app.config.trakable.respond_to?(:ignored_attrs)
        end
      end
    end
  end
end
