# frozen_string_literal: true

require 'rails/generators'

module Trakable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Creates a migration for the traks table.'

      def copy_migration
        template 'create_traks.rb', 'db/migrate/create_traks.rb'
      end
    end
  end
end
