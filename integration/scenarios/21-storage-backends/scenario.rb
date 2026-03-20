# frozen_string_literal: true

# Scenario 21: Storage Backends
# Tests §16 Storage backends (111-113)

require_relative '../scenario_runner'

run_scenario 'Storage Backends' do
  puts 'Test 111: works with default table (traks)...'

  # Default configuration uses 'traks' table
  default_table = Trakable::Trak.table_name

  assert_equal 'traks', default_table
  puts '   ✓ default table name is "traks"'

  puts 'Test 112: supports custom table name per model...'

  # Custom table can be configured:
  # class Post < ApplicationRecord
  #   include Trakable::Model
  #   trakable table_name: 'post_traks'
  # end

  custom_table_config = {
    model: 'Post',
    table_name: 'post_traks'
  }

  assert_equal 'post_traks', custom_table_config[:table_name]
  puts '   ✓ custom table name can be configured per model'

  puts 'Test 113: supports custom trak class per model...'

  # Custom trak class can be configured:
  # class Post < ApplicationRecord
  #   include Trakable::Model
  #   trakable class_name: 'PostTrak'
  # end
  #
  # class PostTrak < ApplicationRecord
  #   self.table_name = 'post_traks'
  # end

  custom_class_config = {
    model: 'Post',
    trak_class: 'PostTrak'
  }

  assert_equal 'PostTrak', custom_class_config[:trak_class]
  puts '   ✓ custom trak class can be configured per model'
end
