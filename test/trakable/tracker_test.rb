# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/trakable/tracker'

class TrackerTest < Minitest::Test
  def setup
    @record = MockRecord.new(1, 'Test content', 'Old Title')
    @record.previous_changes = { 'title' => %w[Old\ Title New\ Title], 'status' => [0, 1] }
    Trakable::Context.reset!
  end

  def teardown
    Trakable::Context.reset!
  end

  # Basic build
  def test_builds_trak_for_update_event
    trak = Trakable::Tracker.call(@record, 'update')

    assert_instance_of Trakable::Trak, trak
    assert_equal 'MockRecord', trak.item_type
    assert_equal 1, trak.item_id
    assert_equal 'update', trak.event
  end

  def test_builds_trak_for_create_event
    trak = Trakable::Tracker.call(@record, 'create')

    assert_equal 'create', trak.event
    assert_nil trak.object
  end

  def test_builds_trak_for_destroy_event
    trak = Trakable::Tracker.call(@record, 'destroy')

    assert_equal 'destroy', trak.event
    assert trak.object
  end

  # Skip when disabled
  def test_skips_when_trakable_disabled
    Trakable.configuration.enabled = false

    trak = Trakable::Tracker.call(@record, 'update')

    assert_nil trak
  ensure
    Trakable.configuration.enabled = true
  end

  def test_skips_when_tracking_disabled_in_context
    Trakable::Context.without_tracking do
      trak = Trakable::Tracker.call(@record, 'update')

      assert_nil trak
    end
  end

  # Whodunnit
  def test_includes_whodunnit_from_context
    actor = MockActor.new(42)
    Trakable::Context.whodunnit = actor

    trak = Trakable::Tracker.call(@record, 'update')

    assert_equal 'MockActor', trak.whodunnit_type
    assert_equal 42, trak.whodunnit_id
  end

  def test_whodunnit_nil_when_not_set
    trak = Trakable::Tracker.call(@record, 'update')

    assert_nil trak.whodunnit_type
    assert_nil trak.whodunnit_id
  end

  # Metadata
  def test_includes_metadata_from_context
    Trakable::Context.metadata = { 'ip' => '127.0.0.1' }

    trak = Trakable::Tracker.call(@record, 'update')

    assert_equal({ 'ip' => '127.0.0.1' }, trak.metadata)
  end

  # Changeset
  def test_changeset_contains_previous_changes_for_update
    trak = Trakable::Tracker.call(@record, 'update')

    assert trak.changeset.key?('title')
    assert trak.changeset.key?('status')
  end

  def test_changeset_empty_for_destroy
    trak = Trakable::Tracker.call(@record, 'destroy')

    assert_equal({}, trak.changeset)
  end

  # Object state
  def test_object_nil_for_create
    trak = Trakable::Tracker.call(@record, 'create')

    assert_nil trak.object
  end

  def test_object_present_for_destroy
    trak = Trakable::Tracker.call(@record, 'destroy')

    assert trak.object
    assert_equal 'Test content', trak.object['content']
  end

  # Tracker class
  def test_tracker_initialization
    tracker = Trakable::Tracker.new(@record, 'update')

    assert_equal @record, tracker.record
    assert_equal 'update', tracker.event
  end

  def test_tracker_class_method_call
    trak = Trakable::Tracker.call(@record, 'update')

    assert_instance_of Trakable::Trak, trak
  end

  # Filter options
  def test_only_option_filters_changeset
    @record.trakable_options = { only: [:title] }

    trak = Trakable::Tracker.call(@record, 'update')

    assert trak.changeset.key?('title')
    refute trak.changeset.key?('status')
  end

  def test_only_option_as_string_filters_changeset
    @record.trakable_options = { only: ['title'] }

    trak = Trakable::Tracker.call(@record, 'update')

    assert trak.changeset.key?('title')
    refute trak.changeset.key?('status')
  end

  def test_ignore_option_filters_changeset
    @record.trakable_options = { ignore: [:status] }

    trak = Trakable::Tracker.call(@record, 'update')

    assert trak.changeset.key?('title')
    refute trak.changeset.key?('status')
  end

  def test_ignore_option_as_string_filters_changeset
    @record.trakable_options = { ignore: ['status'] }

    trak = Trakable::Tracker.call(@record, 'update')

    assert trak.changeset.key?('title')
    refute trak.changeset.key?('status')
  end

  def test_combined_only_and_ignore_options
    @record.trakable_options = { only: %i[title status], ignore: [:status] }

    trak = Trakable::Tracker.call(@record, 'update')

    assert trak.changeset.key?('title')
    refute trak.changeset.key?('status')
  end

  def test_global_ignored_attrs_filters_changeset
    Trakable.configuration.ignored_attrs = [:status]

    trak = Trakable::Tracker.call(@record, 'update')

    assert trak.changeset.key?('title')
    refute trak.changeset.key?('status')
  ensure
    Trakable.configuration.ignored_attrs = nil
  end

  def test_empty_previous_changes_returns_empty_changeset
    @record.previous_changes = {}

    trak = Trakable::Tracker.call(@record, 'update')

    assert_equal({}, trak.changeset)
  end

  def test_filter_changeset_with_no_trakable_options
    record = MockRecordWithEmptyOptions.new(1)
    record.previous_changes = { 'title' => %w[Old New] }

    trak = Trakable::Tracker.call(record, 'update')

    assert trak.changeset.key?('title')
  end

  # Skip conditions
  def test_skips_when_if_condition_returns_false
    @record.trakable_options = { if: proc { false } }

    trak = Trakable::Tracker.call(@record, 'update')

    assert_nil trak
  end

  def test_skips_when_unless_condition_returns_true
    @record.trakable_options = { unless: proc { true } }

    trak = Trakable::Tracker.call(@record, 'update')

    assert_nil trak
  end

  def test_tracks_when_if_condition_returns_true
    @record.trakable_options = { if: proc { true } }

    trak = Trakable::Tracker.call(@record, 'update')

    assert trak
  end

  def test_tracks_when_unless_condition_returns_false
    @record.trakable_options = { unless: proc { false } }

    trak = Trakable::Tracker.call(@record, 'update')

    assert trak
  end
end

# Mock classes for testing
class MockRecord
  attr_accessor :id, :content, :title, :status, :previous_changes, :trakable_options

  def initialize(id, content, title)
    @id = id
    @content = content
    @title = title
    @status = 0
    @previous_changes = {}
    @trakable_options = {}
  end

  def attributes
    { 'id' => @id, 'content' => @content, 'title' => @title, 'status' => @status }
  end
end

class MockActor
  attr_reader :id

  def initialize(id)
    @id = id
  end
end

# Mock record with empty trakable_options for testing filter without options
class MockRecordWithEmptyOptions
  attr_accessor :id, :content, :title, :status, :previous_changes, :trakable_options

  def initialize(id)
    @id = id
    @content = 'Content'
    @title = 'Title'
    @status = 0
    @previous_changes = {}
    @trakable_options = {}
  end

  def attributes
    { 'id' => @id, 'content' => @content, 'title' => @title, 'status' => @status }
  end
end
