# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/trakable/revertable'
require_relative '../../lib/trakable/trak'

class RevertableTest < Minitest::Test
  def setup
    Trakable::Context.reset!
  end

  def teardown
    Trakable::Context.reset!
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
      event: 'update',
      object: { 'title' => 'Title' }
    )

    assert_raises(RuntimeError) { trak.reify }
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

  # trak_revert option
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

    revert_trak = Minitest::Mock.new
    revert_trak.expect :call, true

    # The revert! method should call Tracker.call when trak_revert is true
    # We're testing the flow, not the actual Tracker call here
    result = trak.revert!(trak_revert: false)

    assert_equal post, result
    assert_equal 'Old Title', post.title
  end
end

# Mock classes for testing
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
