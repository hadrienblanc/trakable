#!/usr/bin/env ruby
# frozen_string_literal: true

# Unified Benchmark for Trakable
# Measures 5 dimensions in one run: Boot, Speed, Memory, Storage, Integration
#
# Usage:
#   ruby benchmark/full_benchmark.rb
#   ruby benchmark/full_benchmark.rb > /tmp/before.txt
#   # ... apply changes ...
#   ruby benchmark/full_benchmark.rb > /tmp/after.txt
#   diff /tmp/before.txt /tmp/after.txt

ENV['DISABLE_COVERAGE'] = '1'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'benchmark'
require 'json'
require 'trakable'

SPEED_ITERATIONS = 50_000
SPEED_RUNS = 5
ALLOC_ITERATIONS = 10_000

results = {}

# ---------------------------------------------------------------------------
# A. Boot — subprocess `ruby -e "require 'trakable'"` × 5, median
# ---------------------------------------------------------------------------
boot_times = 5.times.map do
  cmd = %(ruby -I#{File.expand_path('../lib', __dir__)} -e "require 'trakable'")
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  system(cmd, out: File::NULL, err: File::NULL)
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ((t1 - t0) * 1_000_000).round(0)
end.sort
results['boot_time_us'] = boot_times[2] # median

# ---------------------------------------------------------------------------
# Mocks
# ---------------------------------------------------------------------------
class BenchRecord
  attr_accessor :trakable_options, :previous_changes

  def initialize
    @trakable_options = { only: %w[title body], ignore: %w[status] }
    @previous_changes = {
      'title' => %w[OldTitle NewTitle],
      'body'  => %w[OldBody NewBody],
      'views' => [0, 10],
      'updated_at' => [Time.now - 3600, Time.now],
      'status' => %w[draft published]
    }
  end

  def id = 1
  def self.name = 'BenchRecord'

  def attributes
    { 'id' => 1, 'title' => 'NewTitle', 'body' => 'NewBody',
      'views' => 10, 'status' => 'published' }
  end
end

class WideRecord
  attr_accessor :trakable_options, :previous_changes

  def initialize
    @trakable_options = {}
    @previous_changes = {
      'field_03' => %w[old new],
      'field_07' => %w[old new]
    }
  end

  def id = 2
  def self.name = 'WideRecord'

  def attributes
    h = { 'id' => 2 }
    20.times { |i| h["field_#{format('%02d', i)}"] = "value_#{i}" }
    h
  end
end

# ---------------------------------------------------------------------------
# B. Speed — Benchmark.realtime × SPEED_ITERATIONS × SPEED_RUNS, median
# ---------------------------------------------------------------------------
def median_speed(record, event)
  # warmup
  100.times { Trakable::Tracker.call(record, event) }

  runs = SPEED_RUNS.times.map do
    t = Benchmark.realtime { SPEED_ITERATIONS.times { Trakable::Tracker.call(record, event) } }
    (t / SPEED_ITERATIONS * 1_000_000).round(2)
  end.sort
  runs[2]
end

bench = BenchRecord.new
results['speed_create_us'] = median_speed(bench, 'create')
results['speed_update_us'] = median_speed(bench, 'update')
results['speed_destroy_us'] = median_speed(bench, 'destroy')

# ---------------------------------------------------------------------------
# C. Memory — GC.stat[:total_allocated_objects] × ALLOC_ITERATIONS
# ---------------------------------------------------------------------------
def measure_allocs(record, event)
  # warmup
  100.times { Trakable::Tracker.call(record, event) }

  GC.start
  GC.disable
  before = GC.stat[:total_allocated_objects]
  ALLOC_ITERATIONS.times { Trakable::Tracker.call(record, event) }
  after = GC.stat[:total_allocated_objects]
  GC.enable
  ((after - before).to_f / ALLOC_ITERATIONS).round(1)
end

def measure_allocs_breakdown(record, event)
  100.times { Trakable::Tracker.call(record, event) }

  GC.start
  GC.disable
  before = ObjectSpace.count_objects.dup
  ALLOC_ITERATIONS.times { Trakable::Tracker.call(record, event) }
  after = ObjectSpace.count_objects
  GC.enable

  result = {}
  after.each do |type, count|
    diff = count - (before[type] || 0)
    result[type] = (diff.to_f / ALLOC_ITERATIONS).round(1) if diff > 0
  end
  result
end

bench = BenchRecord.new
results['allocs_create'] = measure_allocs(bench, 'create')
results['allocs_update'] = measure_allocs(bench, 'update')
results['allocs_destroy'] = measure_allocs(bench, 'destroy')

breakdown = measure_allocs_breakdown(bench, 'update')
breakdown.each do |type, val|
  results["allocs_update_#{type}"] = val
end

# ---------------------------------------------------------------------------
# D. Storage — JSON.generate(trak.object).bytesize
# ---------------------------------------------------------------------------
def storage_metrics(record, event, prefix)
  trak = Trakable::Tracker.call(record, event)
  result = {}
  obj = trak.object
  cs  = trak.changeset

  result["#{prefix}object_bytes"]    = obj ? JSON.generate(obj).bytesize : 0
  result["#{prefix}changeset_bytes"] = cs && !cs.empty? ? JSON.generate(cs).bytesize : 0
  result["#{prefix}total_bytes"]     = result["#{prefix}object_bytes"] + result["#{prefix}changeset_bytes"]
  result
end

bench = BenchRecord.new
results.merge!(storage_metrics(bench, 'update', 'storage_'))
results.merge!(storage_metrics(bench, 'destroy', 'storage_destroy_'))

wide = WideRecord.new
results.merge!(storage_metrics(wide, 'update', 'storage_wide_'))

# ---------------------------------------------------------------------------
# E. Integration — Load scenarios with GC counting
# ---------------------------------------------------------------------------
scenarios_dir = File.expand_path('../integration/scenarios', __dir__)
if Dir.exist?(scenarios_dir)
  scenario_dirs = Dir.glob("#{scenarios_dir}/*").select { |d| File.directory?(d) }.sort
  total_allocs = 0
  scenario_count = 0

  real_stdout = $stdout

  scenario_dirs.each do |dir|
    scenario_file = File.join(dir, 'scenario.rb')
    next unless File.exist?(scenario_file)

    Trakable::Context.reset!
    $stdout = File.open(File::NULL, 'w')

    GC.start
    GC.disable
    before = GC.stat[:total_allocated_objects]

    begin
      load scenario_file
    rescue StandardError
      # skip failures
    end

    after = GC.stat[:total_allocated_objects]
    GC.enable

    $stdout.close
    $stdout = real_stdout

    total_allocs += (after - before)
    scenario_count += 1
  end

  $stdout = real_stdout
  results['integration_scenarios'] = scenario_count
  results['integration_total_allocs'] = total_allocs
end

# ---------------------------------------------------------------------------
# Output — sorted table, diffable
# ---------------------------------------------------------------------------
puts format('%-40s | %s', 'metric', 'value')
puts '-' * 60
results.sort_by { |k, _| k }.each do |key, value|
  puts format('%-40s | %s', key, value)
end
