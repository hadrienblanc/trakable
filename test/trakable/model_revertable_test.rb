# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/trakable/revertable'

class ModelRevertableTest < Minitest::Test
  def setup
    Trakable::Context.reset!
    @model = MockModelWithTraks.new(1)
  end

  def teardown
    Trakable::Context.reset!
  end

  # trak_at
  def test_trak_at_returns_nil_before_creation
    @model.created_at = Time.now + 3600
    result = @model.trak_at(Time.now)

    assert_nil result
  end

  def test_trak_at_returns_current_state_when_no_traks
    @model.created_at = Time.now - 3600
    result = @model.trak_at(Time.now)

    assert_instance_of MockModelWithTraks, result
    refute result.persisted?
    assert_equal 'Current Title', result.title
  end

  def test_trak_at_returns_state_from_trak
    @model.created_at = Time.now - 3600
    trak_time = Time.now - 1800
    trak = MockTrak.new(
      item_type: 'MockModelWithTraks',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Old Title' },
      created_at: trak_time
    )
    @model.traks_array = [trak]

    result = @model.trak_at(trak_time + 1)

    assert_instance_of MockModelWithTraks, result
    assert_equal 'Old Title', result.title
  end

  def test_trak_at_returns_dup_when_no_matching_trak
    @model.created_at = Time.now - 3600
    @model.traks_array = []

    result = @model.trak_at(Time.now)

    assert_instance_of MockModelWithTraks, result
    assert_equal @model.title, result.title
    refute result.persisted?
  end

  def test_trak_at_finds_closest_trak_before_timestamp
    @model.created_at = Time.now - 3600
    trak1 = MockTrak.new(
      item_type: 'MockModelWithTraks',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'First Title' },
      created_at: Time.now - 3000
    )
    trak2 = MockTrak.new(
      item_type: 'MockModelWithTraks',
      item_id: 1,
      event: 'update',
      object: { 'title' => 'Second Title' },
      created_at: Time.now - 2000
    )
    @model.traks_array = [trak1, trak2]

    result = @model.trak_at(Time.now - 1500)

    assert_equal 'Second Title', result.title
  end

  def test_trak_at_returns_dup_when_trak_reify_is_nil
    @model.created_at = Time.now - 3600
    trak = MockTrak.new(
      item_type: 'MockModelWithTraks',
      item_id: 1,
      event: 'create',
      object: nil,
      created_at: Time.now - 1800
    )
    @model.traks_array = [trak]

    result = @model.trak_at(Time.now)

    assert_instance_of MockModelWithTraks, result
    refute result.persisted?
  end

  def test_trak_at_handles_datetime_input
    @model.created_at = Time.now - 3600
    @model.traks_array = []

    result = @model.trak_at(DateTime.now)

    assert_instance_of MockModelWithTraks, result
  end

  def test_trak_at_returns_nil_when_model_has_no_created_at
    @model.define_singleton_method(:created_at) { nil }
    @model.traks_array = []

    # Should still work since created_at is nil
    result = @model.trak_at(Time.now)

    assert_instance_of MockModelWithTraks, result
  end

  def test_trak_at_returns_nil_when_model_does_not_respond_to_created_at
    model_without_created_at = MockModelWithoutCreatedAt.new(1)
    model_without_created_at.traks_array = []

    result = model_without_created_at.trak_at(Time.now)

    assert_instance_of MockModelWithoutCreatedAt, result
  end

  def test_trak_at_with_timestamp_before_created_at
    @model.created_at = Time.now
    @model.traks_array = []

    result = @model.trak_at(Time.now - 3600)

    assert_nil result
  end
end

# Mock Trak for testing
class MockTrak
  include Trakable::Revertable

  attr_accessor :item_type, :item_id, :event, :object, :created_at

  def initialize(attrs = {})
    attrs.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def create?
    event == 'create'
  end

  def update?
    event == 'update'
  end

  def destroy?
    event == 'destroy'
  end
end

# Mock Model with traks for testing
class MockModelWithTraks
  include Trakable::ModelRevertable

  attr_accessor :id, :title, :created_at, :traks_array

  def initialize(id = nil)
    @id = id
    @title = 'Current Title'
    @created_at = Time.now
    @traks_array = []
  end

  def traks
    @traks_array
  end

  def persisted?
    !!@id
  end

  def attributes
    { 'id' => @id, 'title' => @title }
  end

  def write_attribute(attr, value)
    instance_variable_set("@#{attr}", value)
  end

  def respond_to?(method, include_all: false)
    %i[id title].include?(method.to_sym) || super
  end
end

# Mock Model without created_at for testing
class MockModelWithoutCreatedAt
  include Trakable::ModelRevertable

  attr_accessor :id, :title, :traks_array

  def initialize(id)
    @id = id
    @title = 'Title'
    @traks_array = []
  end

  def traks
    @traks_array
  end

  def persisted?
    !!@id
  end

  def attributes
    { 'id' => @id, 'title' => @title }
  end

  def write_attribute(attr, value)
    instance_variable_set("@#{attr}", value)
  end

  def respond_to?(method, include_all: false)
    %i[id title].include?(method.to_sym) || super
  end
end
