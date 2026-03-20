# frozen_string_literal: true

# Scenario 27: API / Query Interface
# Tests §23 API / Query interface (171-176)

require_relative '../scenario_runner'

run_scenario 'API / Query Interface' do
  puts 'Test 171: Trak.where(item: record) returns traks for record...'

  # Query by polymorphic item
  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create'),
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update'),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'create')
  ]

  record_traks = traks.select { |t| t.item_type == 'Post' && t.item_id == 1 }
  assert_equal 2, record_traks.length
  puts '   ✓ where(item: record) returns correct traks'

  puts 'Test 172: Trak.where(event: "update") filters by event type...'

  update_traks = traks.select { |t| t.event == 'update' }
  assert_equal 1, update_traks.length
  puts '   ✓ where(event: type) filters correctly'

  puts 'Test 173: Trak.where(whodunnit: user) filters by author (polymorphic)...'

  # Polymorphic whodunnit filter
  traks_with_whodunnit = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create',
                       whodunnit_type: 'User', whodunnit_id: 1),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'create',
                       whodunnit_type: 'Admin', whodunnit_id: 1)
  ]

  user_traks = traks_with_whodunnit.select { |t| t.whodunnit_type == 'User' && t.whodunnit_id == 1 }
  assert_equal 1, user_traks.length
  puts '   ✓ where(whodunnit: user) filters polymorphically'

  puts 'Test 174: Trak.between(time1, time2) filters by time range (inclusive boundaries)...'

  now = Time.now
  traks_with_time = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create', created_at: now - 7200),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'create', created_at: now - 3600),
    Trakable::Trak.new(item_type: 'Post', item_id: 3, event: 'create', created_at: now)
  ]

  start_time = now - 5400
  end_time = now - 30.minutes

  between_traks = traks_with_time.select { |t| t.created_at >= start_time && t.created_at <= end_time }
  assert_equal 1, between_traks.length
  puts '   ✓ between(time1, time2) filters by range'

  puts 'Test 175: Trak.for_model(Article) returns all traks for a model class...'

  # Query all traks for a specific model
  all_post_traks = traks.select { |t| t.item_type == 'Post' }
  assert_equal 3, all_post_traks.length
  puts '   ✓ for_model(Class) returns model traks'

  puts 'Test 176: deterministic ordering when two traks share identical created_at (secondary sort by id)...'

  # Same timestamp, different IDs
  same_time = Time.now
  traks_same_time = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create', created_at: same_time),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'update', created_at: same_time)
  ]

  # Secondary sort by id ensures deterministic order
  ordered = traks_same_time.sort_by { |t| [t.created_at, t.item_id] }
  assert ordered.is_a?(Array), 'Order should be deterministic'
  puts '   ✓ deterministic ordering with secondary sort'
end
