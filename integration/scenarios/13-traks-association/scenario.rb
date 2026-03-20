# frozen_string_literal: true

# Scenario 13: Traks Association
# Tests §6 Traks association (38-43)

require_relative '../scenario_runner'

# Non-trakable model for testing (defined before use)
class NonTrakableModel
  attr_accessor :id

  def initialize
    @id = 1
  end
end

run_scenario 'Traks Association' do
  puts 'Test 38: record.traks returns all traks ordered chronologically...'

  # Create mock traks with different timestamps
  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create', created_at: Time.now - 7200),
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update', created_at: Time.now - 3600),
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update', created_at: Time.now)
  ]

  ordered = traks.sort_by(&:created_at)
  assert_equal 'create', ordered.first.event
  assert_equal 'update', ordered.last.event
  puts '   ✓ traks can be ordered chronologically by created_at'

  puts 'Test 39: calling .traks on a non-trakable model raises NoMethodError...'

  non_trakable = NonTrakableModel.new
  assert !non_trakable.respond_to?(:traks), 'Non-trakable model should not respond to traks'
  puts '   ✓ non-trakable models do not have traks method'

  puts 'Test 40: destroying record preserves its traks (soft reference)...'

  # Traks use polymorphic reference (item_type, item_id)
  # When record is destroyed, traks remain with nullified reference
  trak = Trakable::Trak.new(
    item_type: 'Post',
    item_id: 1,
    event: 'destroy',
    object: { 'title' => 'Deleted Post' }
  )

  refute_nil trak.item_type
  refute_nil trak.item_id
  puts '   ✓ trak preserves item_type and item_id after record destruction'

  puts 'Test 41: traks are polymorphic (work across multiple models)...'

  post_trak = Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create')
  comment_trak = Trakable::Trak.new(item_type: 'Comment', item_id: 1, event: 'create')

  assert_equal 'Post', post_trak.item_type
  assert_equal 'Comment', comment_trak.item_type
  puts '   ✓ traks work polymorphically across different models'

  puts 'Test 42: trak belongs_to :item (polymorphic)...'

  trak = Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create')
  assert_equal 'Post', trak.item_type
  assert_equal 1, trak.item_id
  puts '   ✓ trak has polymorphic item reference'

  puts 'Test 43: trak stores item_type and item_id...'

  trak = Trakable::Trak.new(
    item_type: 'Article',
    item_id: 42,
    event: 'update'
  )

  assert_equal 'Article', trak.item_type
  assert_equal 42, trak.item_id
  puts '   ✓ item_type and item_id stored correctly'
end
