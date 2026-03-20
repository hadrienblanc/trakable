# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/trakable/revertable'
require_relative '../../lib/trakable/trak'

# Mock classes for testing - must be defined before tests
# rubocop:disable Naming/PredicateMethod
class MockPost
  attr_accessor :id, :title, :body

  @records = {}

  class << self
    attr_accessor :records
  end

  def self.find_by(id:)
    records[id]
  end

  def initialize(id = nil, title = nil, body = nil)
    @id = id
    @title = title
    @body = body
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

  def save!(*)
    true
  end

  def delete
    MockPost.records.delete(@id)
    true
  end

  def attributes
    { 'id' => @id, 'title' => @title, 'body' => @body }
  end
end
# rubocop:enable Naming/PredicateMethod

# rubocop:disable Metrics/ClassLength
class RevertableTest < Minitest::Test
  def setup
    Trakable::Context.reset!
    MockPost.records.clear
  end

  def teardown
    Trakable::Context.reset!
    MockPost.records.clear
  end

  # reify
  def test_reify_returns_nil_for_create_event
    trak = Trakable::Trak.new(
      item_type: 'Post',
      item_id: 1,
      event: 'create',
      object: nil
    )

    assert_nil trak.reify
  end

  def test_reify_returns_non_persisted_record_for_update_event
    MockPost.records[1] = MockPost.new(1, 'Current Title', 'Current Body')

    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Old Title', 'body' => 'Old Body' }
    )

    reified = trak.reify

    assert_instance_of MockPost, reified
    assert_equal 'Old Title', reified.title
    assert_equal 'Old Body', reified.body
    refute reified.persisted?
  end

  def test_reify_returns_non_persisted_record_for_destroy_event
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'destroy',
      object: { 'title' => 'Deleted Post', 'body' => 'Deleted Body' }
    )

    reified = trak.reify

    assert_instance_of MockPost, reified
    assert_equal 'Deleted Post', reified.title
    refute reified.persisted?
  end

  def test_reify_ignores_unknown_attributes
    MockPost.records[1] = MockPost.new(1, 'Current', 'Body')

    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Title', 'unknown_attr' => 'value' }
    )

    reified = trak.reify

    assert_equal 'Title', reified.title
    refute reified.respond_to?(:unknown_attr)
  end

  def test_reify_raises_for_unknown_model_class
    trak = Trakable::Trak.new(
      item_type: 'NonExistentClass',
      item_id: 1,
      event: 'destroy',
      object: { 'title' => 'Title' }
    )

    assert_raises(RuntimeError) { trak.reify }
  end

  def test_reify_returns_nil_for_update_with_unknown_model_class
    trak = Trakable::Trak.new(
      item_type: 'NonExistentClass',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Title' }
    )

    assert_nil trak.reify
  end

  # revert! for create event
  def test_revert_create_deletes_record
    post = MockPost.new(1, 'Title', 'Body')
    MockPost.records[1] = post

    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'create',
      object: nil
    )
    trak.define_singleton_method(:item) { post }
    post.define_singleton_method(:destroy) { delete }

    result = trak.revert!

    assert result
    refute MockPost.records.key?(1)
  end

  # revert! for update event
  def test_revert_update_restores_previous_state
    post = MockPost.new(1, 'New Title', 'New Body')
    MockPost.records[1] = post

    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Old Title', 'body' => 'Old Body' }
    )
    trak.define_singleton_method(:item) { post }

    result = trak.revert!

    assert_equal post, result
    assert_equal 'Old Title', post.title
    assert_equal 'Old Body', post.body
  end

  # revert! for destroy event
  def test_revert_destroy_recreates_record
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'destroy',
      object: { 'title' => 'Deleted Title', 'body' => 'Deleted Body' }
    )

    result = trak.revert!

    assert_instance_of MockPost, result
    assert_equal 'Deleted Title', result.title
    assert_equal 'Deleted Body', result.body
  end

  # trak_revert option tests - test that Tracker.call is invoked
  def test_revert_with_trak_revert_creates_revert_trak
    post = MockPost.new(1, 'New Title', 'New Body')
    MockPost.records[1] = post

    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Old Title', 'body' => 'Old Body' }
    )
    trak.define_singleton_method(:item) { post }

    # Track if Tracker.call was invoked
    tracker_called = false
    original_tracker_call = Trakable::Tracker.method(:call)
    Trakable::Tracker.define_singleton_method(:call) do |_item, event|
      tracker_called = true
      # Create a mock trak to return
      Trakable::Trak.new(item_type: 'MockPost', item_id: 1, event: event)
    end

    result = trak.revert!(trak_revert: true)

    assert_equal post, result
    assert tracker_called

    # Restore original method
    Trakable::Tracker.define_singleton_method(:call, original_tracker_call)
  end

  def test_revert_destroy_with_trak_revert_creates_revert_trak
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'destroy',
      object: { 'title' => 'Deleted Title', 'body' => 'Deleted Body' }
    )

    tracker_called = false
    original_tracker_call = Trakable::Tracker.method(:call)
    Trakable::Tracker.define_singleton_method(:call) do |_item, event|
      tracker_called = true
      Trakable::Trak.new(item_type: 'MockPost', item_id: 1, event: event)
    end

    result = trak.revert!(trak_revert: true)

    assert_instance_of MockPost, result
    assert tracker_called

    Trakable::Tracker.define_singleton_method(:call, original_tracker_call)
  end

  def test_revert_create_with_trak_revert_calls_tracker
    post = MockPost.new(1, 'Title', 'Body')
    MockPost.records[1] = post

    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'create',
      object: nil
    )
    trak.define_singleton_method(:item) { post }
    post.define_singleton_method(:destroy) { delete }

    tracker_called = false
    original_tracker_call = Trakable::Tracker.method(:call)
    Trakable::Tracker.define_singleton_method(:call) do |_item, event|
      tracker_called = true
      Trakable::Trak.new(item_type: 'MockPost', item_id: 1, event: event)
    end

    result = trak.revert!(trak_revert: true)

    assert result
    assert tracker_called

    Trakable::Tracker.define_singleton_method(:call, original_tracker_call)
  end

  # revert! edge cases
  def test_revert_create_returns_false_when_no_item
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 999,
      event: 'create',
      object: nil
    )
    trak.define_singleton_method(:item) { nil }

    result = trak.revert!

    refute result
  end

  def test_revert_update_returns_false_when_no_item
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 999,
      event: 'update',
      object: { 'title' => 'Title' }
    )
    trak.define_singleton_method(:item) { nil }

    result = trak.revert!

    refute result
  end

  def test_revert_update_returns_false_when_no_reified
    post = MockPost.new(1, 'Title', 'Body')
    MockPost.records[1] = post

    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'update',
      object: nil
    )
    trak.define_singleton_method(:item) { post }

    result = trak.revert!

    refute result
  end

  def test_revert_destroy_returns_false_when_no_object
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 999,
      event: 'destroy',
      object: nil
    )

    result = trak.revert!

    refute result
  end

  # reify edge case: deleted item with delta storage
  def test_reify_returns_nil_for_update_when_item_deleted
    # Simulates delta storage: object only has changed attrs
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 999,
      event: 'update',
      object: { 'title' => 'Old Title' }
    )
    # item_id 999 does not exist in MockPost.records → item returns nil

    assert_nil trak.reify
  end

  def test_reify_works_for_update_when_item_exists
    post = MockPost.new(1, 'Current Title', 'Current Body')
    MockPost.records[1] = post

    # Delta: only title changed
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Old Title' }
    )

    reified = trak.reify

    assert_instance_of MockPost, reified
    assert_equal 'Old Title', reified.title
    assert_equal 'Current Body', reified.body
    refute reified.persisted?
  end

  def test_reify_works_for_destroy_when_item_deleted
    # Destroy traks store full snapshot, so reify works without live item
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 999,
      event: 'destroy',
      object: { 'title' => 'Deleted', 'body' => 'Deleted Body' }
    )

    reified = trak.reify

    assert_instance_of MockPost, reified
    assert_equal 'Deleted', reified.title
    assert_equal 'Deleted Body', reified.body
  end

  def test_revert_update_returns_false_when_item_deleted_with_delta
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 999,
      event: 'update',
      object: { 'title' => 'Old Title' }
    )
    trak.define_singleton_method(:item) { nil }

    result = trak.revert!

    refute result
  end

  # reify edge case: empty object
  def test_reify_returns_nil_for_empty_object
    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'update',
      object: {}
    )

    assert_nil trak.reify
  end

  # reify with record that doesn't respond to attribute
  def test_reify_skips_unknown_attributes_on_model
    MockPost.records[1] = MockPost.new(1, 'Current', 'Body')

    trak = Trakable::Trak.new(
      item_type: 'MockPost',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Title', 'unknown_field' => 'value' }
    )

    reified = trak.reify

    assert_equal 'Title', reified.title
    # unknown_field should be skipped
    refute reified.respond_to?(:unknown_field)
  end
end
# rubocop:enable Metrics/ClassLength
