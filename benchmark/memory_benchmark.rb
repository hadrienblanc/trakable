#!/usr/bin/env ruby
# frozen_string_literal: true

# Memory & Allocation Benchmark for Trakable
# Measures object allocations and GC pressure for common operations
#
# Usage:
#   ruby benchmark/memory_benchmark.rb

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'trakable'

puts '=' * 60
puts 'Trakable Memory & Allocation Benchmark'
puts '=' * 60
puts

ITERATIONS = 10_000

# --- Helpers ---

def measure_allocs(n = ITERATIONS)
  GC.start
  GC.disable
  before = GC.stat[:total_allocated_objects]
  n.times { yield }
  after = GC.stat[:total_allocated_objects]
  GC.enable
  (after - before).to_f / n
end

def measure_allocs_by_type(n = ITERATIONS)
  GC.start
  GC.disable
  before = ObjectSpace.count_objects.dup
  n.times { yield }
  after = ObjectSpace.count_objects
  GC.enable
  result = {}
  after.each do |type, count|
    diff = count - (before[type] || 0)
    result[type] = (diff.to_f / n).round(1) if diff > 0
  end
  result
end

def measure_memory_bytes(n = ITERATIONS)
  GC.start
  before = GC.stat[:malloc_increase_bytes]
  n.times { yield }
  after = GC.stat[:malloc_increase_bytes]
  ((after - before).to_f / n).round(1)
end

# --- Mock ---

class MockRecord
  attr_accessor :trakable_options, :previous_changes

  def initialize
    @trakable_options = { only: %w[title body], ignore: %w[status] }
    @previous_changes = {
      'title' => %w[Old New], 'body' => %w[Old New],
      'views' => [0, 10], 'updated_at' => [Time.now - 3600, Time.now],
      'status' => %w[draft published]
    }
  end

  def id
    1
  end

  def attributes
    { 'id' => 1, 'title' => 'New', 'body' => 'New', 'views' => 10, 'status' => 'published' }
  end
end

# --- Tests ---

record = MockRecord.new

# Warmup
5.times { Trakable::Tracker.call(record, 'update') }

puts "1. Full Tracker.call (update with only/ignore)"
puts '-' * 50
allocs = measure_allocs { Trakable::Tracker.call(record, 'update') }
types = measure_allocs_by_type { Trakable::Tracker.call(record, 'update') }
puts "   Allocations per call: #{allocs.round(1)}"
puts "   Breakdown: #{types.select { |_, v| v > 0 }.map { |k, v| "#{k}=#{v}" }.join(', ')}"
puts

puts "2. Tracker.call (create, no changeset)"
puts '-' * 50
allocs = measure_allocs { Trakable::Tracker.call(record, 'create') }
types = measure_allocs_by_type { Trakable::Tracker.call(record, 'create') }
puts "   Allocations per call: #{allocs.round(1)}"
puts "   Breakdown: #{types.select { |_, v| v > 0 }.map { |k, v| "#{k}=#{v}" }.join(', ')}"
puts

puts "3. Tracker.call (destroy, full object state)"
puts '-' * 50
allocs = measure_allocs { Trakable::Tracker.call(record, 'destroy') }
types = measure_allocs_by_type { Trakable::Tracker.call(record, 'destroy') }
puts "   Allocations per call: #{allocs.round(1)}"
puts "   Breakdown: #{types.select { |_, v| v > 0 }.map { |k, v| "#{k}=#{v}" }.join(', ')}"
puts

puts "4. Trak.build only"
puts '-' * 50
allocs = measure_allocs { Trakable::Trak.build(item: record, event: 'update', changeset: {}, object: {}) }
types = measure_allocs_by_type { Trakable::Trak.build(item: record, event: 'update', changeset: {}, object: {}) }
puts "   Allocations per call: #{allocs.round(1)}"
puts "   Breakdown: #{types.select { |_, v| v > 0 }.map { |k, v| "#{k}=#{v}" }.join(', ')}"
puts

puts "5. filter_changeset only"
puts '-' * 50
tracker = Trakable::Tracker.new(record, 'update')
allocs = measure_allocs { tracker.send(:filter_changeset, record.previous_changes) }
puts "   Allocations per call: #{allocs.round(1)}"
puts

puts "6. build_object_from_previous only"
puts '-' * 50
allocs = measure_allocs { tracker.send(:build_object_from_previous) }
puts "   Allocations per call: #{allocs.round(1)}"
puts

# No-filter scenario
record_no_filter = MockRecord.new
record_no_filter.trakable_options = {}
puts "7. Tracker.call (update, no model filters)"
puts '-' * 50
allocs = measure_allocs { Trakable::Tracker.call(record_no_filter, 'update') }
puts "   Allocations per call: #{allocs.round(1)}"
puts

puts '=' * 60
puts 'Memory Benchmark Complete'
puts '=' * 60
