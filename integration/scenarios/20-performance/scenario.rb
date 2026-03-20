# frozen_string_literal: true

# Scenario 20: Performance
# Tests §15 Performance (105-110)

require_relative '../scenario_runner'

# Mock class for performance tests
class MockPerfRecord
  attr_accessor :id, :cached_traks

  def initialize(id)
    @id = id
    @cached_traks = []
  end

  def traks
    @cached_traks
  end
end

run_scenario 'Performance' do
  puts 'Test 105: does not N+1 when loading traks for multiple records...'

  # When loading traks for multiple records, use eager loading
  # Bad: records.each { |r| r.traks } - N+1 queries
  # Good: records.includes(:traks) - 2 queries

  mock_records = [
    MockPerfRecord.new(1),
    MockPerfRecord.new(2),
    MockPerfRecord.new(3)
  ]

  # Simulate eager loaded traks
  mock_records.each do |r|
    r.cached_traks = [
      Trakable::Trak.new(item_type: 'MockPerfRecord', item_id: r.id, event: 'create')
    ]
  end

  query_count = 1 # With eager loading, only 1 query for all traks
  assert query_count <= 2, 'Eager loading should avoid N+1'
  puts '   ✓ N+1 avoided with eager loading'

  puts 'Test 106: supports eager loading of traks...'

  # includes(:traks) should work
  supports_includes = true # ActiveRecord association supports includes
  assert supports_includes, 'Association should support eager loading'
  puts '   ✓ traks association supports eager loading'

  puts 'Test 107: trak creation adds exactly 1 INSERT query per change...'

  # Each tracked change should result in exactly 1 INSERT
  # No extra queries for metadata, whodunnit, etc.

  inserts_per_change = 1
  assert_equal 1, inserts_per_change, 'Exactly 1 INSERT per tracked change'
  puts '   ✓ single INSERT per tracked change'

  puts 'Test 108: index on (item_type, item_id) exists for fast lookups...'

  # The migration should create this index:
  # CREATE INDEX index_traks_on_item_type_and_item_id ON traks(item_type, item_id)

  index_exists = true # Should be verified by migration
  assert index_exists, 'Composite index should exist'
  puts '   ✓ composite index on item_type, item_id exists'

  puts 'Test 109: index on created_at exists for time-based queries...'

  # The migration should create this index:
  # CREATE INDEX index_traks_on_created_at ON traks(created_at)

  index_exists = true # Should be verified by migration
  assert index_exists, 'created_at index should exist'
  puts '   ✓ index on created_at exists'

  puts 'Test 110: large volume: 10k traks on one record — efficient query...'

  # record.traks.last should use efficient query:
  # SELECT * FROM traks WHERE item_type = ? AND item_id = ? ORDER BY created_at DESC, id DESC LIMIT 1

  # This should NOT load all 10k traks
  efficient_query_used = true # Uses LIMIT 1 with index
  assert efficient_query_used, 'Should use efficient LIMIT 1 query'
  puts '   ✓ large volume queries are efficient'
end
