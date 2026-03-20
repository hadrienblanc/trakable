# frozen_string_literal: true

module Trakable
  class Railtie < ::Rails::Railtie
    generators do
      require 'generators/trakable/install_generator'
    end
  end
end
