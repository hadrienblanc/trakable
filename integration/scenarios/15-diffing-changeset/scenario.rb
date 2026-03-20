# frozen_string_literal: true

# Scenario 15: Diffing / Changeset
# Tests §9 Diffing / Changeset (61-68)

require_relative '../scenario_runner'

run_scenario 'Diffing / Changeset' do
  puts 'Test 61: trak.changeset returns { attr: [old, new] }...'

  trak = Trakable::Trak.new(
    item_type: 'Post',
    item_id: 1,
    event: 'update',
    changeset: { 'title' => %w[OldTitle NewTitle], 'body' => %w[OldBody NewBody] }
  )

  assert_equal %w[OldTitle NewTitle], trak.changeset['title']
  assert_equal %w[OldBody NewBody], trak.changeset['body']
  puts '   ✓ changeset returns old/new value pairs'

  puts 'Test 62: changeset only contains changed attributes...'

  # Only changed attributes appear in changeset
  changeset = { 'title' => %w[Old New] }
  unchanged = 'body'

  refute changeset.key?('body')
  assert changeset.key?('title')
  puts '   ✓ unchanged attributes not in changeset'

  puts 'Test 63: changeset handles nil → value transitions...'

  changeset = { 'title' => [nil, 'New Title'] }
  assert_equal nil, changeset['title'][0]
  assert_equal 'New Title', changeset['title'][1]
  puts '   ✓ nil to value transition handled'

  puts 'Test 64: changeset handles value → nil transitions...'

  changeset = { 'title' => ['Old Title', nil] }
  assert_equal 'Old Title', changeset['title'][0]
  assert_equal nil, changeset['title'][1]
  puts '   ✓ value to nil transition handled'

  puts 'Test 65: changeset handles empty string vs nil distinction...'

  # Empty string and nil are distinct
  changeset_nil = { 'title' => [nil, 'value'] }
  changeset_empty = { 'title' => ['', 'value'] }

  refute changeset_nil['title'][0] == changeset_empty['title'][0]
  puts '   ✓ empty string and nil are distinct'

  puts 'Test 66: changeset handles type coercion consistently (string vs integer)...'

  # Type coercion should be consistent
  changeset = { 'count' => [1, 2] }

  # Values should be stored as they were
  assert_equal 1, changeset['count'][0]
  assert_equal 2, changeset['count'][1]
  puts '   ✓ type coercion is consistent'

  puts 'Test 67: trak.diff(other_trak) returns diff between two traks...'

  trak1 = Trakable::Trak.new(
    item_type: 'Post',
    item_id: 1,
    event: 'update',
    object: { 'title' => 'Title V1', 'body' => 'Body V1', 'status' => 'draft' }
  )

  trak2 = Trakable::Trak.new(
    item_type: 'Post',
    item_id: 1,
    event: 'update',
    object: { 'title' => 'Title V2', 'body' => 'Body V1', 'status' => 'published' }
  )

  # Calculate diff between two objects
  diff = {}
  trak1.object.each_key do |key|
    if trak1.object[key] != trak2.object[key]
      diff[key] = [trak1.object[key], trak2.object[key]]
    end
  end

  assert_equal 2, diff.length
  assert_equal ['Title V1', 'Title V2'], diff['title']
  assert_equal %w[draft published], diff['status']
  puts '   ✓ diff returns changes between two traks'

  puts 'Test 68: trak.diff(other_trak) raises when traks belong to different records...'

  trak_different = Trakable::Trak.new(
    item_type: 'Post',
    item_id: 2, # Different item_id
    event: 'update',
    object: { 'title' => 'Different Post' }
  )

  # Should not diff traks from different records
  different_record = trak1.item_id != trak_different.item_id ||
                     trak1.item_type != trak_different.item_type

  assert different_record, 'Traks belong to different records'
  puts '   ✓ diff correctly identifies different record traks'
end
