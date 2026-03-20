# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/trakable/cleanup'

class CleanupTest < Minitest::Test
  def setup
    Trakable::Context.reset!
  end

  def teardown
    Trakable::Context.reset!
  end

  # Cleanup.run
  def test_cleanup_returns_true_when_no_max_traks_configured
    record = CleanupMockRecord.new(trakable_options: {})

    result = Trakable::Cleanup.run(record)

    assert result
  end

  def test_cleanup_enforces_max_traks_when_configured
    record = CleanupMockRecordWithTraks.new(trakable_options: { max_traks: 2 })
    # 4 traks, max 2 → should delete 2 oldest
    record.traks_data = [
      { id: 1, created_at: Time.now - 400 },
      { id: 2, created_at: Time.now - 300 },
      { id: 3, created_at: Time.now - 200 },
      { id: 4, created_at: Time.now - 100 }
    ]

    Trakable::Cleanup.run(record)

    assert_equal 2, record.traks_data.size
    assert_equal [3, 4], record.traks_data.map { |t| t[:id] }.sort
  end

  def test_cleanup_noop_when_record_has_no_traks_method
    record = CleanupMockRecord.new(trakable_options: { max_traks: 5 })

    result = Trakable::Cleanup.run(record)

    assert result
  end

  # Cleanup.run_retention
  def test_run_retention_returns_nil_when_no_retention_configured
    model_class = CleanupMockModel

    result = Trakable::Cleanup.run_retention(model_class)

    assert_nil result
  end

  def test_run_retention_with_retention_period
    model_class = CleanupMockModelWithRetention

    result = Trakable::Cleanup.run_retention(model_class)

    assert_equal 0, result
  end

  def test_run_retention_with_override_period
    model_class = CleanupMockModel
    retention = 90 * 24 * 60 * 60 # 90 days in seconds

    result = Trakable::Cleanup.run_retention(model_class, retention_period: retention)

    assert_equal 0, result
  end

  def test_run_retention_accepts_batch_size
    model_class = CleanupMockModelWithRetention

    result = Trakable::Cleanup.run_retention(model_class, batch_size: 500)

    assert_equal 0, result
  end
end

# Mock classes for testing

# Mock record with traks supporting AR-like chaining
class CleanupMockRecordWithTraks
  attr_reader :trakable_options
  attr_accessor :traks_data

  def initialize(trakable_options: {})
    @trakable_options = trakable_options
    @traks_data = []
  end

  def traks
    CleanupMockRelation.new(self)
  end
end

# Minimal AR-like relation for testing cleanup chaining
class CleanupMockRelation
  def initialize(record)
    @record = record
  end

  def respond_to?(method, include_all = false)
    %i[where order offset delete_all].include?(method) || super
  end

  def order(*)
    @sorted = @record.traks_data.sort_by { |t| -t[:created_at].to_f }
    self
  end

  def offset(n)
    @sorted = (@sorted || @record.traks_data).drop(n)
    self
  end

  def delete_all
    ids_to_delete = @sorted.map { |t| t[:id] }
    @record.traks_data.reject! { |t| ids_to_delete.include?(t[:id]) }
  end
end

class CleanupMockRecord
  attr_reader :trakable_options

  def initialize(trakable_options: {})
    @trakable_options = trakable_options
  end
end

class CleanupMockModel
  def self.trakable_options
    {}
  end
end

class CleanupMockModelWithRetention
  def self.trakable_options
    { retention: 90 * 24 * 60 * 60 } # 90 days in seconds
  end
end
