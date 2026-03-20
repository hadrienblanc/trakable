# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/trakable/trak'

class TrakTest < Minitest::Test
  # Constants
  def test_events_constant
    assert_equal %w[create update destroy], Trakable::Trak::EVENTS
  end

  def test_table_name
    assert_equal 'traks', Trakable::Trak.table_name
  end

  # Initialization
  def test_initialize_with_attributes
    trak = Trakable::Trak.new(
      item_type: 'Post',
      item_id: 42,
      event: 'create'
    )

    assert_equal 'Post', trak.item_type
    assert_equal 42, trak.item_id
    assert_equal 'create', trak.event
  end

  def test_initialize_with_nil_attributes
    trak = Trakable::Trak.new

    assert_nil trak.item_type
    assert_nil trak.item_id
    assert_nil trak.event
  end

  def test_initialize_sets_all_attributes
    time = Time.now
    trak = Trakable::Trak.new(
      id: 1,
      item_type: 'Post',
      item_id: 2,
      event: 'update',
      object: { 'title' => 'Old' },
      changeset: { 'title' => ['Old', 'New'] },
      whodunnit_type: 'User',
      whodunnit_id: 3,
      metadata: { 'ip' => '127.0.0.1' },
      created_at: time
    )

    assert_equal 1, trak.id
    assert_equal 'Post', trak.item_type
    assert_equal 2, trak.item_id
    assert_equal 'update', trak.event
    assert_equal({ 'title' => 'Old' }, trak.object)
    assert_equal({ 'title' => %w[Old New] }, trak.changeset)
    assert_equal 'User', trak.whodunnit_type
    assert_equal 3, trak.whodunnit_id
    assert_equal({ 'ip' => '127.0.0.1' }, trak.metadata)
    assert_equal time, trak.created_at
  end

  # JSON Serialization - object
  def test_object_serialization
    trak = Trakable::Trak.new
    trak.object = { 'title' => 'Test', 'count' => 5 }

    assert_equal({ 'title' => 'Test', 'count' => 5 }, trak.object)
  end

  def test_object_returns_nil_when_nil
    trak = Trakable::Trak.new
    trak.object = nil

    assert_nil trak.object
  end

  def test_object_handles_empty_string_as_nil
    trak = Trakable::Trak.new(object_raw: '')

    assert_nil trak.object
  end

  def test_object_handles_nested_hash
    nested = { 'user' => { 'name' => 'John', 'id' => 1 } }
    trak = Trakable::Trak.new
    trak.object = nested

    assert_equal nested, trak.object
  end

  # JSON Serialization - changeset
  def test_changeset_serialization
    trak = Trakable::Trak.new
    trak.changeset = { 'title' => %w[Old New], 'status' => [0, 1] }

    assert_equal({ 'title' => %w[Old New], 'status' => [0, 1] }, trak.changeset)
  end

  def test_changeset_returns_nil_when_nil
    trak = Trakable::Trak.new
    trak.changeset = nil

    assert_nil trak.changeset
  end

  # JSON Serialization - metadata
  def test_metadata_serialization
    trak = Trakable::Trak.new
    trak.metadata = { 'ip' => '127.0.0.1', 'user_agent' => 'Chrome' }

    assert_equal({ 'ip' => '127.0.0.1', 'user_agent' => 'Chrome' }, trak.metadata)
  end

  def test_metadata_returns_nil_when_nil
    trak = Trakable::Trak.new
    trak.metadata = nil

    assert_nil trak.metadata
  end

  # Event type helpers
  def test_create_returns_true_for_create_event
    trak = Trakable::Trak.new(event: 'create')

    assert trak.create?
    refute trak.update?
    refute trak.destroy?
  end

  def test_update_returns_true_for_update_event
    trak = Trakable::Trak.new(event: 'update')

    refute trak.create?
    assert trak.update?
    refute trak.destroy?
  end

  def test_destroy_returns_true_for_destroy_event
    trak = Trakable::Trak.new(event: 'destroy')

    refute trak.create?
    refute trak.update?
    assert trak.destroy?
  end

  def test_custom_event_not_create_update_destroy
    trak = Trakable::Trak.new(event: 'publish')

    refute trak.create?
    refute trak.update?
    refute trak.destroy?
  end

  # Item accessor
  def test_item_returns_nil_without_type
    trak = Trakable::Trak.new(item_id: 1)

    assert_nil trak.item
  end

  def test_item_returns_nil_without_id
    trak = Trakable::Trak.new(item_type: 'Post')

    assert_nil trak.item
  end

  # Whodunnit accessor
  def test_whodunnit_returns_nil_without_type
    trak = Trakable::Trak.new(whodunnit_id: 1)

    assert_nil trak.whodunnit
  end

  def test_whodunnit_returns_nil_without_id
    trak = Trakable::Trak.new(whodunnit_type: 'User')

    assert_nil trak.whodunnit
  end

  # Build class method
  def test_build_creates_trak_with_all_attributes
    item = MockItem.new(1)
    actor = MockActor.new(42)

    trak = Trakable::Trak.build(
      item: item,
      event: 'update',
      changeset: { 'title' => %w[Old New] },
      object: { 'title' => 'Old' },
      whodunnit: actor,
      metadata: { 'ip' => '127.0.0.1' }
    )

    assert_equal 'MockItem', trak.item_type
    assert_equal 1, trak.item_id
    assert_equal 'update', trak.event
    assert_equal({ 'title' => 'Old' }, trak.object)
    assert_equal({ 'title' => %w[Old New] }, trak.changeset)
    assert_equal 'MockActor', trak.whodunnit_type
    assert_equal 42, trak.whodunnit_id
    assert_equal({ 'ip' => '127.0.0.1' }, trak.metadata)
    assert trak.created_at
  end

  def test_build_with_nil_whodunnit
    item = MockItem.new(1)

    trak = Trakable::Trak.build(
      item: item,
      event: 'create',
      changeset: {}
    )

    assert_nil trak.whodunnit_type
    assert_nil trak.whodunnit_id
  end
end

# Mock classes for testing
class MockItem
  attr_reader :id

  def initialize(id)
    @id = id
  end

  def to_s
    'MockItem'
  end
end

class MockActor
  attr_reader :id

  def initialize(id)
    @id = id
  end

  def to_s
    'MockActor'
  end
end
