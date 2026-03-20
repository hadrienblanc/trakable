# frozen_string_literal: true

require 'test_helper'
require 'rails/generators'
require_relative '../../lib/generators/trakable/install_generator'

class InstallGeneratorTest < Minitest::Test
  TEMPLATE_PATH = File.expand_path('../../lib/generators/trakable/templates/create_traks_migration.rb', __dir__)

  def template_content
    @template_content ||= File.read(TEMPLATE_PATH)
  end

  # Template content tests
  def test_template_exists
    assert File.exist?(TEMPLATE_PATH), 'Template file should exist'
  end

  def test_template_contains_traks_table
    content = template_content

    assert_includes content, 'create_table :traks'
    assert_includes content, 't.string   :item_type,      null: false'
    assert_includes content, 't.bigint   :item_id,        null: false'
    assert_includes content, 't.string   :event,          null: false'
    assert_includes content, 't.text     :object'
    assert_includes content, 't.text     :changeset'
    assert_includes content, 't.string   :whodunnit_type'
    assert_includes content, 't.bigint   :whodunnit_id'
    assert_includes content, 't.text     :metadata'
    assert_includes content, 't.datetime :created_at, null: false'
  end

  def test_template_contains_indexes
    content = template_content

    assert_includes content, 'add_index :traks, %i[item_type item_id]'
    assert_includes content, 'add_index :traks, :created_at'
    assert_includes content, 'add_index :traks, %i[whodunnit_type whodunnit_id]'
    assert_includes content, 'add_index :traks, :event'
  end

  def test_template_uses_change_method_for_reversibility
    content = template_content

    assert_includes content, 'def change'
    refute_includes content, 'def up'
    refute_includes content, 'def down'
  end

  def test_template_has_frozen_string_literal
    assert_includes template_content, '# frozen_string_literal: true'
  end

  # Generator class tests
  def test_generator_class_exists
    assert defined?(Trakable::Generators::InstallGenerator)
  end

  def test_generator_inherits_from_rails_generator_base
    generator = Trakable::Generators::InstallGenerator
    assert_includes generator.ancestors, Rails::Generators::Base
  end

  def test_generator_has_correct_source_root
    generator = Trakable::Generators::InstallGenerator
    source_root = generator.source_root

    assert File.directory?(source_root), 'Source root should be a directory'
    assert File.exist?(File.join(source_root, 'create_traks_migration.rb'))
  end

  # Method coverage tests
  def test_next_migration_number_returns_timestamp_format
    timestamp = Trakable::Generators::InstallGenerator.next_migration_number('/some/dir')

    assert_match(/^\d{14}$/, timestamp)
  end

  def test_copy_migration_calls_migration_template
    generator = Trakable::Generators::InstallGenerator.new([], destination_root: '/tmp')
    called = false
    args = nil

    generator.define_singleton_method(:migration_template) do |*a|
      called = true
      args = a
    end

    generator.copy_migration

    assert called
    assert_equal 'create_traks_migration.rb', args[0]
    assert_equal 'db/migrate/create_traks.rb', args[1]
  end

  def test_copy_initializer_calls_template
    generator = Trakable::Generators::InstallGenerator.new([], destination_root: '/tmp')
    called = false
    args = nil

    generator.define_singleton_method(:template) do |*a|
      called = true
      args = a
    end

    generator.copy_initializer

    assert called
    assert_equal 'trakable_initializer.rb', args[0]
    assert_equal 'config/initializers/trakable.rb', args[1]
  end
end
