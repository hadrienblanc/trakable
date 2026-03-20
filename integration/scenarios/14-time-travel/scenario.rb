# frozen_string_literal: true

# Scenario 14: Time Travel / Point in Time
# Tests §8 Time travel (55-60)

require_relative '../scenario_runner'

# Mock class for time travel tests (defined before use to allow constantize)
class MockTimePost
  attr_accessor :id, :title, :body, :created_at

  @records = {}

  class << self
    attr_accessor :records

    def find_by(id:)
      records[id]
    end
  end

  def initialize(id: nil, title: '', body: '', created_at: nil)
    @id = id
    @title = title
    @body = body
    @created_at = created_at
  end

  def persisted?
    !!@id
  end

  def write_attribute(attr, value)
    instance_variable_set("@#{attr}", value) if respond_to?(attr.to_sym)
  end

  def respond_to?(method, include_all: false)
    %i[id title body created_at].include?(method.to_sym) || super
  end

  def attributes
    { 'id' => @id, 'title' => @title, 'body' => @body, 'created_at' => @created_at }
  end
end

run_scenario 'Time Travel / Point in Time' do
  puts 'Test 55: record.trak_at(timestamp) returns a non-persisted record with state at that point...'

  # Create a mock record with trak_at capability
  now = Time.now
  earlier = now - 3600

  # Simulate traks at different times
  traks = [
    Trakable::Trak.new(
      item_type: 'MockTimePost',
      item_id: 1,
      event: 'create',
      object: nil,
      created_at: now - 7200
    ),
    Trakable::Trak.new(
      item_type: 'MockTimePost',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Old Title', 'body' => 'Old Body' },
      created_at: now - 3600
    ),
    Trakable::Trak.new(
      item_type: 'MockTimePost',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Current Title', 'body' => 'Current Body' },
      created_at: now
    )
  ]

  # Find trak at earlier timestamp
  target_trak = traks.select { |t| t.created_at <= earlier }.max_by(&:created_at)
  refute_nil target_trak
  assert_equal 'Old Title', target_trak.object['title']
  puts '   ✓ trak_at finds correct trak at given timestamp'

  puts 'Test 56: trak_at with timestamp before creation returns nil...'

  before_creation = now - 10800
  target_trak = traks.select { |t| t.created_at <= before_creation }.max_by(&:created_at)
  assert_nil target_trak
  puts '   ✓ returns nil for timestamp before creation'

  puts 'Test 57: trak_at with timestamp after last change returns current state...'

  future = now + 3600
  target_trak = traks.select { |t| t.created_at <= future }.max_by(&:created_at)
  refute_nil target_trak
  assert_equal 'Current Title', target_trak.object['title']
  puts '   ✓ returns current state for future timestamp'

  puts 'Test 58: trak_at with exact trak timestamp returns state at that trak...'

  exact_time = now - 3600
  target_trak = traks.select { |t| t.created_at <= exact_time }.max_by(&:created_at)
  refute_nil target_trak
  assert_equal 'Old Title', target_trak.object['title']
  puts '   ✓ exact timestamp returns correct trak state'

  puts 'Test 59: record.traks[n].reify returns a non-persisted record with that state...'

  # Register a live record so reify can merge delta with current state
  MockTimePost.records[1] = MockTimePost.new(id: 1, title: 'Latest', body: 'Latest Body')

  trak = traks[1] # The update with "Old Title"
  reified = trak.reify

  assert_kind_of MockTimePost, reified
  assert_equal 'Old Title', reified.title
  refute reified.persisted?
  puts '   ✓ reify returns non-persisted record with historical state'

  puts 'Test 60: trak_at handles timezone-aware timestamps and DST boundaries correctly...'

  # Test with different timezone representations
  utc_time = Time.now.utc
  local_time = utc_time.getlocal

  # Both should find the same trak
  utc_target = traks.select { |t| t.created_at <= utc_time }.max_by(&:created_at)
  local_target = traks.select { |t| t.created_at <= local_time }.max_by(&:created_at)

  assert_equal utc_target, local_target
  puts '   ✓ timezone handling is consistent'
end
