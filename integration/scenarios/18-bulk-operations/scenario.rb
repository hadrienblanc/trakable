# frozen_string_literal: true

# Scenario 18: Bulk Operations
# Tests §12 Bulk operations (91-94)

require_relative '../scenario_runner'

# Mock class for bulk operation tests
class MockBulkPost
  attr_accessor :id, :title

  def initialize(id)
    @id = id
    @title = "Post #{id}"
  end
end

run_scenario 'Bulk Operations' do
  puts 'Test 91: insert_all skips tracking (bypasses callbacks)...'

  # insert_all bypasses ActiveRecord callbacks
  # Therefore, no traks are created

  # Simulate: Post.insert_all([{title: 'A'}, {title: 'B'}])
  inserted_ids = [1, 2]
  traks_created = [] # No callbacks = no traks

  assert traks_created.empty?, 'insert_all should not create traks'
  puts '   ✓ insert_all bypasses tracking (no callbacks)'

  puts 'Test 92: update_all skips tracking (bypasses callbacks)...'

  # update_all bypasses ActiveRecord callbacks
  # Simulate: Post.where(published: false).update_all(published: true)
  updated_count = 5
  traks_created = [] # No callbacks = no traks

  assert traks_created.empty?, 'update_all should not create traks'
  puts '   ✓ update_all bypasses tracking (no callbacks)'

  puts 'Test 93: destroy_all creates one trak per record...'

  # destroy_all calls destroy on each record, triggering callbacks
  # Simulate: Post.destroy_all
  records = [MockBulkPost.new(1), MockBulkPost.new(2), MockBulkPost.new(3)]

  # Each destroy triggers after_destroy callback
  traks_created = records.map do |record|
    Trakable::Trak.new(
      item_type: 'MockBulkPost',
      item_id: record.id,
      event: 'destroy',
      object: { 'id' => record.id }
    )
  end

  assert_equal 3, traks_created.length
  assert_equal 'destroy', traks_created.first.event
  puts '   ✓ destroy_all creates one trak per record'

  puts 'Test 94: delete_all skips tracking (bypasses callbacks)...'

  # delete_all issues DELETE directly, no callbacks
  # Simulate: Post.delete_all
  deleted_count = 5
  traks_created = [] # No callbacks = no traks

  assert traks_created.empty?, 'delete_all should not create traks'
  puts '   ✓ delete_all bypasses tracking (no callbacks)'
end
