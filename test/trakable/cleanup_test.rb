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

    assert result
  end

  def test_run_retention_with_override_period
    model_class = CleanupMockModel
    retention = 90 * 24 * 60 * 60 # 90 days in seconds

    result = Trakable::Cleanup.run_retention(model_class, retention_period: retention)

    assert result
  end
end

# Mock classes for testing
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
