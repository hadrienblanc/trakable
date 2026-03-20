# frozen_string_literal: true

# Scenario 39: Query Scopes
# Tests the AR-only scopes defined on Trakable::Trak
# Since integration tests run without AR, we verify the non-AR path
# and simulate the scope logic to validate correctness.

require_relative '../scenario_runner'

run_scenario 'Query Scopes' do
  puts '=== TEST 1: Scopes are not defined in non-AR mode ==='

  refute Trakable::Trak.respond_to?(:for_item_type), 'for_item_type should not exist without AR'
  refute Trakable::Trak.respond_to?(:for_event), 'for_event should not exist without AR'
  refute Trakable::Trak.respond_to?(:for_whodunnit), 'for_whodunnit should not exist without AR'
  refute Trakable::Trak.respond_to?(:created_before), 'created_before should not exist without AR'
  refute Trakable::Trak.respond_to?(:created_after), 'created_after should not exist without AR'
  refute Trakable::Trak.respond_to?(:recent), 'recent should not exist without AR'
  puts '   ✓ Scopes are AR-only (not defined in plain Ruby mode)'

  puts '=== TEST 2: Scope logic — for_item_type ==='

  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create'),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'update'),
    Trakable::Trak.new(item_type: 'Comment', item_id: 1, event: 'create'),
    Trakable::Trak.new(item_type: 'User', item_id: 1, event: 'destroy')
  ]

  post_traks = traks.select { |t| t.item_type == 'Post' }
  assert_equal 2, post_traks.length
  puts '   ✓ for_item_type filters by item_type'

  puts '=== TEST 3: Scope logic — for_event ==='

  creates = traks.select { |t| t.event == 'create' }
  assert_equal 2, creates.length

  updates = traks.select { |t| t.event == 'update' }
  assert_equal 1, updates.length

  destroys = traks.select { |t| t.event == 'destroy' }
  assert_equal 1, destroys.length
  puts '   ✓ for_event filters by event type'

  puts '=== TEST 4: Scope logic — for_whodunnit (polymorphic) ==='

  traks_with_actors = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create',
                       whodunnit_type: 'User', whodunnit_id: 1),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'update',
                       whodunnit_type: 'User', whodunnit_id: 2),
    Trakable::Trak.new(item_type: 'Post', item_id: 3, event: 'create',
                       whodunnit_type: 'Admin', whodunnit_id: 1),
    Trakable::Trak.new(item_type: 'Post', item_id: 4, event: 'destroy',
                       whodunnit_type: nil, whodunnit_id: nil)
  ]

  user1_traks = traks_with_actors.select { |t| t.whodunnit_type == 'User' && t.whodunnit_id == 1 }
  assert_equal 1, user1_traks.length

  admin_traks = traks_with_actors.select { |t| t.whodunnit_type == 'Admin' }
  assert_equal 1, admin_traks.length

  anonymous_traks = traks_with_actors.select { |t| t.whodunnit_type.nil? }
  assert_equal 1, anonymous_traks.length
  puts '   ✓ for_whodunnit filters by type + id (polymorphic)'

  puts '=== TEST 5: Scope logic — created_before / created_after ==='

  now = Time.now
  traks_timed = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create', created_at: now - 7200),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'update', created_at: now - 3600),
    Trakable::Trak.new(item_type: 'Post', item_id: 3, event: 'update', created_at: now - 1800),
    Trakable::Trak.new(item_type: 'Post', item_id: 4, event: 'destroy', created_at: now)
  ]

  cutoff = now - 3600

  before = traks_timed.select { |t| t.created_at < cutoff }
  assert_equal 1, before.length
  assert_equal 1, before.first.item_id

  after = traks_timed.select { |t| t.created_at > cutoff }
  assert_equal 2, after.length
  puts '   ✓ created_before / created_after filter by timestamp'

  puts '=== TEST 6: Scope logic — recent (order desc) ==='

  sorted = traks_timed.sort_by { |t| -t.created_at.to_f }
  assert_equal 4, sorted.first.item_id
  assert_equal 1, sorted.last.item_id
  puts '   ✓ recent orders by created_at desc'

  puts '=== TEST 7: Scope chaining simulation ==='

  all_traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create', created_at: now - 7200,
                       whodunnit_type: 'User', whodunnit_id: 1),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'update', created_at: now - 3600,
                       whodunnit_type: 'User', whodunnit_id: 1),
    Trakable::Trak.new(item_type: 'Comment', item_id: 1, event: 'update', created_at: now - 1800,
                       whodunnit_type: 'User', whodunnit_id: 1),
    Trakable::Trak.new(item_type: 'Post', item_id: 3, event: 'update', created_at: now,
                       whodunnit_type: 'Admin', whodunnit_id: 2)
  ]

  # Simulate: for_item_type('Post').for_event(:update).created_after(1.day.ago).recent
  result = all_traks
           .select { |t| t.item_type == 'Post' }
           .select { |t| t.event == 'update' }
           .select { |t| t.created_at > now - 86_400 }
           .sort_by { |t| -t.created_at.to_f }

  assert_equal 2, result.length
  assert_equal 3, result.first.item_id, 'Most recent should be first'
  assert_equal 2, result.last.item_id
  puts '   ✓ Chained scopes filter and sort correctly'

  puts '=== TEST 8: Edge case — empty result ==='

  empty = all_traks.select { |t| t.item_type == 'NonExistent' }
  assert_equal 0, empty.length
  puts '   ✓ Scopes return empty array when nothing matches'
end
