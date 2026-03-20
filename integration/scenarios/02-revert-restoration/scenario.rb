# frozen_string_literal: true

# Scenario 02: Revert and Restoration
# Tests revert! and reify functionality

require_relative '../scenario_runner'

# Mock class for testing (defined before use)
class MockPost
  attr_accessor :id, :title, :body

  def initialize(id = nil)
    @id = id
    @title = 'Current Title'
    @body = 'Current Body'
  end

  def persisted?
    !!@id
  end

  def write_attribute(attr, value)
    instance_variable_set("@#{attr}", value)
  end

  def respond_to?(method, include_all: false)
    %i[id title body].include?(method.to_sym) || super
  end

  def attributes
    { 'id' => @id, 'title' => @title, 'body' => @body }
  end
end

run_scenario 'Revert and Restoration' do
  puts 'Step 1: Testing reify for update event...'

  trak = Trakable::Trak.new(
    item_type: 'MockPost',
    item_id: 1,
    event: 'update',
    object: { 'title' => 'Old Title', 'body' => 'Old Body' }
  )

  reified = trak.reify

  assert_kind_of MockPost, reified
  assert_equal 'Old Title', reified.title
  assert_equal 'Old Body', reified.body
  refute reified.persisted?
  puts '   ✓ reify returns non-persisted record with previous state'

  puts 'Step 2: Testing reify for create event...'

  create_trak = Trakable::Trak.new(
    item_type: 'MockPost',
    item_id: 1,
    event: 'create',
    object: nil
  )

  assert_equal nil, create_trak.reify
  puts '   ✓ reify returns nil for create events'

  puts 'Step 3: Testing reify for destroy event...'

  destroy_trak = Trakable::Trak.new(
    item_type: 'MockPost',
    item_id: 1,
    event: 'destroy',
    object: { 'title' => 'Deleted Title', 'body' => 'Deleted Body' }
  )

  restored = destroy_trak.reify
  assert_kind_of MockPost, restored
  assert_equal 'Deleted Title', restored.title
  puts '   ✓ reify works for destroy events'

  puts 'Step 4: Testing empty object handling...'

  empty_trak = Trakable::Trak.new(
    item_type: 'MockPost',
    item_id: 1,
    event: 'update',
    object: {}
  )

  assert_equal nil, empty_trak.reify
  puts '   ✓ reify returns nil for empty object'
end
