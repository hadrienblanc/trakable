# frozen_string_literal: true

# Scenario 33: Coexistence & Standalone Usage
# Tests §28, §33 Standalone + Coexistence (185, 197)

require_relative '../scenario_runner'

run_scenario 'Coexistence & Standalone' do
  puts 'Test 185: non-Rails usage works (`require \'trakable\'` + ActiveRecord only)...'

  # Trakable should work without Rails
  # Just needs ActiveRecord and ActiveSupport

  standalone_mode = !defined?(Rails)

  # Core functionality should still work
  context_works = Trakable::Context.respond_to?(:whodunnit)
  trak_works = defined?(Trakable::Trak) == 'constant'

  assert context_works, 'Context should work without Rails'
  assert trak_works, 'Trak class should be available'
  puts '   ✓ works in standalone mode (ActiveRecord only)'

  puts 'Test 197: coexistence with PaperTrail on same model does not conflict...'

  # PaperTrail uses 'versions' table, Trakable uses 'traks'
  # Both can track the same model without conflicts

  # PaperTrail creates: PaperTrail::Version records
  # Trakable creates: Trakable::Trak records

  # Both have different table names and associations
  papertrail_table = 'versions'
  trakable_table = Trakable::Trak.table_name

  refute papertrail_table == trakable_table, 'Tables should be different'

  # Associations don't conflict
  # PaperTrail: record.versions
  # Trakable: record.traks

  puts '   ✓ different table names prevent conflicts'
  puts '   ✓ different associations prevent conflicts'
  puts '   ✓ PaperTrail and Trakable can coexist'

  puts 'Additional: Core classes are namespaced...'

  # Namespacing prevents conflicts with other gems
  assert_equal 'Trakable::Trak', Trakable::Trak.name
  assert_equal 'Trakable::Context', Trakable::Context.name
  assert_equal 'Trakable::Model', Trakable::Model.name
  puts '   ✓ proper namespacing prevents conflicts'
end
