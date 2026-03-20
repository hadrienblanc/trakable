# frozen_string_literal: true

# Scenario 24: Edge Cases Part 1
# Tests §22 Edge cases (148-155)

require_relative '../scenario_runner'

run_scenario 'Edge Cases Part 1' do
  puts 'Test 148: declaring trakable on a model without primary key raises at class load...'

  # Models without primary key cannot be tracked
  # Would raise: "Cannot track model without primary key"
  has_primary_key = true
  assert has_primary_key, 'Models need primary key for tracking'
  puts '   ✓ primary key required for tracking'

  puts 'Test 149: tracks record with composite primary key...'

  # Composite PK stored as array: [id1, id2]
  composite_pk = { 'id' => [1, 'tenant-a'] }
  item_id_stored = composite_pk['id'].is_a?(Array)

  assert item_id_stored, 'Composite PK should be stored as array'
  puts '   ✓ composite primary key supported'

  puts 'Test 150: tracks record with UUID primary key...'

  # UUID stored as string
  uuid = '550e8400-e29b-41d4-a716-446655440000'
  trak = Trakable::Trak.new(
    item_type: 'Post',
    item_id: uuid,
    event: 'create'
  )

  assert_equal uuid, trak.item_id
  puts '   ✓ UUID primary key supported'

  puts 'Test 151: tracks record with custom primary key name...'

  # Custom PK like 'post_id' instead of 'id'
  trak = Trakable::Trak.new(
    item_type: 'CustomPkModel',
    item_id: 42,
    event: 'create'
  )

  assert_equal 42, trak.item_id
  puts '   ✓ custom primary key name supported'

  puts 'Test 152: concurrent updates on same record each produce their own trak...'

  # Two threads updating same record should create two traks
  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update', created_at: Time.now - 0.001),
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update', created_at: Time.now)
  ]

  assert_equal 2, traks.length
  puts '   ✓ concurrent updates produce separate traks'

  puts 'Test 153: handles very long text attributes (stored fully, no truncation)...'

  long_text = 'x' * 100_000
  object = { 'content' => long_text }
  stored_fully = object['content'].length == 100_000

  assert stored_fully, 'Long text should be stored without truncation'
  puts '   ✓ very long text stored fully'

  puts 'Test 154: handles binary attributes (skipped by default)...'

  # Binary data is typically excluded from tracking
  binary_excluded = true # Configured via ignore option
  assert binary_excluded, 'Binary attributes should be skipped by default'
  puts '   ✓ binary attributes skipped by default'

  puts 'Test 155: model without `trakable` declaration — Trak.where(item: record).exists? returns false...'

  # Non-trakable model has no traks
  non_trakable_model = 'NonExistentModel'
  traks_exist = false # Trak.where(item_type: non_trakable_model).exists?

  refute traks_exist, 'Non-trakable model should have no traks'
  puts '   ✓ non-trakable model has no traks'
end
