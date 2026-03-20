# frozen_string_literal: true

# rubocop:disable Naming/PredicatePrefix
require 'test_helper'
require_relative '../../lib/trakable/model'

class ModelTest < Minitest::Test
  def setup
    Trakable::Context.reset!
  end

  def teardown
    Trakable::Context.reset!
  end

  # DSL
  def test_trakable_method_exists
    assert MockModel.respond_to?(:trakable)
  end

  def test_trakable_sets_options
    MockModel.trakable(only: %i[title], ignore: %i[views])

    assert_equal({ only: %i[title], ignore: %i[views] }, MockModel.trakable_options)
  end

  def test_trakable_options_empty_by_default
    assert_equal({}, MockModelWithoutTrakable.trakable_options)
  end

  # Callbacks registration
  def test_registers_create_callback_when_create_in_events
    callbacks = MockModelWithCreate.registered_callbacks

    assert_includes callbacks, :trak_create
  end

  def test_registers_update_callback_when_update_in_events
    callbacks = MockModelWithUpdate.registered_callbacks

    assert_includes callbacks, :trak_update
  end

  def test_registers_destroy_callback_when_destroy_in_events
    callbacks = MockModelWithDestroy.registered_callbacks

    assert_includes callbacks, :trak_destroy
  end

  def test_registers_all_callbacks_by_default
    callbacks = MockModel.registered_callbacks

    assert_includes callbacks, :trak_create
    assert_includes callbacks, :trak_update
    assert_includes callbacks, :trak_destroy
  end

  # Callback calls Tracker
  def test_trak_create_calls_tracker
    mock = MockModel.new(1)
    trak = Trakable::Tracker.call(mock, 'create')

    assert trak
  end

  def test_trak_update_calls_tracker
    mock = MockModel.new(1)
    mock.previous_changes = { 'title' => %w[Old New] }
    trak = Trakable::Tracker.call(mock, 'update')

    assert trak
  end

  def test_trak_destroy_calls_tracker
    mock = MockModel.new(1)
    trak = Trakable::Tracker.call(mock, 'destroy')

    assert trak
  end

  # Callback respects tracking disabled
  def test_trak_create_skips_when_tracking_disabled
    Trakable::Context.without_tracking do
      mock = MockModel.new(1)
      trak = Trakable::Tracker.call(mock, 'create')

      assert_nil trak
    end
  end
end

# Mock callback object to simulate ActiveRecord's callback structure
class MockCallback
  attr_reader :filter

  def initialize(filter)
    @filter = filter
  end
end

# Base mock class with shared callback registration logic
module MockActiveRecord
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def registered_callbacks
      @registered_callbacks ||= []
    end

    def after_create(method_name)
      registered_callbacks << method_name
    end

    def after_update(method_name)
      registered_callbacks << method_name
    end

    def after_destroy(method_name)
      registered_callbacks << method_name
    end

    def has_many(*args)
      # Stub - does nothing in test
    end
  end
end

# Mock classes for testing
class MockModel
  include MockActiveRecord
  include Trakable::Model

  trakable

  attr_accessor :id, :title, :views, :previous_changes

  def initialize(id)
    @id = id
    @title = 'Test'
    @views = 0
    @previous_changes = {}
  end

  def attributes
    { 'id' => @id, 'title' => @title, 'views' => @views }
  end
end

class MockModelWithoutTrakable
  include MockActiveRecord
  include Trakable::Model
end

class MockModelWithCreate
  include MockActiveRecord
  include Trakable::Model

  trakable on: %i[create]
end

class MockModelWithUpdate
  include MockActiveRecord
  include Trakable::Model

  trakable on: %i[update]
end

class MockModelWithDestroy
  include MockActiveRecord
  include Trakable::Model

  trakable on: %i[destroy]
end
# rubocop:enable Naming/PredicatePrefix
