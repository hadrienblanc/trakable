# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module Trakable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Creates a migration and initializer for Trakable.'

      def self.next_migration_number(_dir)
        Time.now.utc.strftime('%Y%m%d%H%M%S')
      end

      def copy_migration
        migration_template 'create_traks_migration.rb', 'db/migrate/create_traks.rb'
      end

      def copy_initializer
        template 'trakable_initializer.rb', 'config/initializers/trakable.rb'
      end
    end
  end
end
