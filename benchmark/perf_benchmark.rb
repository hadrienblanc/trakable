#!/usr/bin/env ruby
# frozen_string_literal: true

# Performance Benchmark for Trakable
# Measures tracking overhead for common operations

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'trakable'
require 'benchmark'

puts "=" * 60
puts "Trakable Performance Benchmark"
puts "=" * 60
puts

# Configuration
ITERATIONS = 50_000

# Test 1: Filter changeset with only + ignore
puts "Test 1: filter_changeset with only/ignore (#{ITERATIONS} iterations)"
puts "-" * 50

# Simulate a record with trakable_options
class MockRecord
  attr_accessor :trakable_options

  def previous_changes
    @previous_changes ||= {
      'title' => ['Old Title', 'New Title'],
      'body' => ['Old Body', 'New Body'],
      'views' => [0, 10],
      'updated_at' => [Time.now - 3600, Time.now],
      'status' => ['draft', 'published']
    }
  end
end

record = MockRecord.new
record.trakable_options = { only: %i[title body], ignore: %i[status] }

tracker = Trakable::Tracker.new(record, 'update')

time = Benchmark.realtime do
  ITERATIONS.times { tracker.send(:filter_changeset, record.previous_changes.dup) }
end

puts "Time: #{(time * 1000).round(2)}ms"
puts "Per iteration: #{(time / ITERATIONS * 1_000_000).round(2)}µs"
baseline_filter = time
puts

# Test 2: Filter changeset without only/ignore (fast path)
puts "Test 2: filter_changeset without filters (#{ITERATIONS} iterations)"
puts "-" * 50

record2 = MockRecord.new
record2.trakable_options = {}
tracker2 = Trakable::Tracker.new(record2, 'update')

time = Benchmark.realtime do
  ITERATIONS.times { tracker2.send(:filter_changeset, record2.previous_changes.dup) }
end

puts "Time: #{(time * 1000).round(2)}ms"
puts "Per iteration: #{(time / ITERATIONS * 1_000_000).round(2)}µs"
puts

# Test 3: String conversion overhead
puts "Test 3: Array().map(&:to_s) overhead (#{ITERATIONS} iterations)"
puts "-" * 50

only_symbols = %i[title body views status]
only_strings = %w[title body views status]

time_symbols = Benchmark.realtime do
  ITERATIONS.times { Array(only_symbols).map(&:to_s) }
end

time_strings = Benchmark.realtime do
  ITERATIONS.times { Array(only_strings).map(&:to_s) }
end

puts "Symbols: #{(time_symbols * 1000).round(2)}ms"
puts "Pre-converted strings: #{(time_strings * 1000).round(2)}ms"
puts "Speedup: #{(time_symbols / time_strings).round(2)}x"
puts

# Test 4: Set vs Array for ignore lookups
puts "Test 4: Set vs Array for ignore lookups (#{ITERATIONS} iterations)"
puts "-" * 50

ignore_array = %w[updated_at created_at id views status]
ignore_set = ignore_array.to_set
keys = %w[title body views status updated_at created_at id]

time_array = Benchmark.realtime do
  ITERATIONS.times { keys.reject { |k| ignore_array.include?(k) } }
end

time_set = Benchmark.realtime do
  ITERATIONS.times { keys.reject { |k| ignore_set.include?(k) } }
end

puts "Array#include?: #{(time_array * 1000).round(2)}ms"
puts "Set#include?: #{(time_set * 1000).round(2)}ms"
puts "Speedup: #{(time_array / time_set).round(2)}x"
puts

# Test 5: respond_to? vs direct check
puts "Test 5: respond_to? overhead (#{ITERATIONS} iterations)"
puts "-" * 50

obj = Object.new

time_respond = Benchmark.realtime do
  ITERATIONS.times { obj.respond_to?(:trakable_options) }
end

time_direct = Benchmark.realtime do
  ITERATIONS.times { obj.is_a?(MockRecord) }
end

puts "respond_to?: #{(time_respond * 1000).round(2)}ms"
puts "is_a?: #{(time_direct * 1000).round(2)}ms"
puts

puts "=" * 60
puts "Benchmark Complete"
puts "Baseline filter_changeset: #{(baseline_filter / ITERATIONS * 1_000_000).round(2)}µs per call"
puts "=" * 60
