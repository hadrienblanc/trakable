# frozen_string_literal: true

module Trakable
  class Railtie < ::Rails::Railtie
    generators do
      require 'generators/trakable/install_generator'
    end

    initializer 'trakable.configure' do |app|
      if app.config.respond_to?(:trakable)
        Trakable.configure do |config|
          config.enabled = app.config.trakable.enabled if app.config.trakable.respond_to?(:enabled)
          config.ignored_attrs = app.config.trakable.ignored_attrs if app.config.trakable.respond_to?(:ignored_attrs)
          if app.config.trakable.respond_to?(:whodunnit_method)
            config.whodunnit_method = app.config.trakable.whodunnit_method
          end
        end
      end
    end

    # Auto-include Controller concern — no manual include needed
    initializer 'trakable.controller' do
      ActiveSupport.on_load(:action_controller_base) do
        include Trakable::Controller
      end
    end
  end
end
