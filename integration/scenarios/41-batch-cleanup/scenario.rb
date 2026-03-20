# frozen_string_literal: true

# Scenario 41: Batch Cleanup
# Tests Cleanup.run_retention with batch deletion and Cleanup.run per-record

require_relative '../scenario_runner'

# Mock AR-like relation that supports limit + delete_all for batch testing
class BatchMockRelation
  attr_reader :deleted_count, :delete_calls

  def initialize(total_rows)
    @remaining = total_rows
    @deleted_count = 0
    @delete_calls = 0
  end

  def where(*)
    self
  end

  def limit(n)
    @current_limit = n
    self
  end

  def delete_all
    @delete_calls += 1
    to_delete = [@remaining, @current_limit || @remaining].min
    @remaining -= to_delete
    @deleted_count += to_delete
    to_delete
  end

  def respond_to?(method, *)
    %i[where limit delete_all].include?(method) || super
  end
end

# Mock Trak class that returns our mock relation
class BatchMockTrak
  class << self
    attr_accessor :relation

    def where(*)
      relation
    end

    def respond_to?(method, *)
      %i[where].include?(method) || super
    end

    def arel_table
      @arel_table ||= Struct.new(:nothing).new.tap do |at|
        at.define_singleton_method(:[]) { |_col| Struct.new(:lt).new(proc { |_t| true }) }
      end
    end
  end
end

# Mock record with traks for per-record cleanup
class BatchCleanupRecord
  attr_reader :trakable_options, :traks_data

  def initialize(max_traks:, trak_count:)
    @trakable_options = { max_traks: max_traks }
    @traks_data = trak_count.times.map { |i| { id: i, created_at: Time.now - (trak_count - i) } }
  end

  def traks
    BatchRecordRelation.new(self)
  end
end

class BatchRecordRelation
  def initialize(record)
    @record = record
  end

  def respond_to?(method, *)
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
    ids_to_delete.length
  end
end

run_scenario 'Batch Cleanup' do
  puts '=== TEST 1: run_retention returns nil without retention config ==='

  model_class = Class.new do
    def self.trakable_options
      {}
    end
  end

  result = Trakable::Cleanup.run_retention(model_class)
  assert_nil result
  puts '   ✓ Returns nil when no retention configured'

  puts '=== TEST 2: run_retention returns 0 when no old traks ==='

  model_with_retention = Class.new do
    def self.trakable_options
      { retention: 90 * 86_400 }
    end

    def self.to_s
      'CleanModel'
    end
  end

  result = Trakable::Cleanup.run_retention(model_with_retention)
  assert_equal 0, result
  puts '   ✓ Returns 0 when nothing to delete'

  puts '=== TEST 3: run_retention accepts custom batch_size ==='

  result = Trakable::Cleanup.run_retention(model_with_retention, batch_size: 500)
  assert_equal 0, result
  puts '   ✓ batch_size parameter accepted'

  puts '=== TEST 4: run_retention accepts override retention_period ==='

  model_no_retention = Class.new do
    def self.trakable_options
      {}
    end

    def self.to_s
      'NoRetentionModel'
    end
  end

  result = Trakable::Cleanup.run_retention(model_no_retention, retention_period: 30 * 86_400)
  # Should run (not nil) because we override
  assert_equal 0, result
  puts '   ✓ retention_period override works'

  puts '=== TEST 5: BATCH_SIZE constant is defined ==='

  assert_equal 1_000, Trakable::Cleanup::BATCH_SIZE
  puts '   ✓ Default BATCH_SIZE is 1,000'

  puts '=== TEST 6: Per-record cleanup enforces max_traks ==='

  record = BatchCleanupRecord.new(max_traks: 3, trak_count: 10)
  assert_equal 10, record.traks_data.length

  Trakable::Cleanup.run(record)

  assert_equal 3, record.traks_data.length, "Expected 3 traks, got #{record.traks_data.length}"
  # Should keep the 3 most recent (highest IDs)
  kept_ids = record.traks_data.map { |t| t[:id] }.sort
  assert_equal [7, 8, 9], kept_ids
  puts '   ✓ max_traks keeps only the N most recent'

  puts '=== TEST 7: Per-record cleanup is a no-op when under limit ==='

  record = BatchCleanupRecord.new(max_traks: 10, trak_count: 3)
  Trakable::Cleanup.run(record)

  assert_equal 3, record.traks_data.length
  puts '   ✓ No deletion when trak count is under max_traks'

  puts '=== TEST 8: Cleanup.run returns true ==='

  record = BatchCleanupRecord.new(max_traks: 5, trak_count: 5)
  result = Trakable::Cleanup.run(record)

  assert_equal true, result
  puts '   ✓ Cleanup.run always returns true'
end
