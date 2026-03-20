#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration Memory Benchmark for Trakable
# Measures allocations across all integration scenarios
#
# Usage:
#   ruby benchmark/integration_memory.rb

ENV['DISABLE_COVERAGE'] = '1'
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'trakable'

scenarios_dir = File.expand_path('../integration/scenarios', __dir__)
scenario_dirs = Dir.glob("#{scenarios_dir}/*").select { |d| File.directory?(d) }.sort

results = []
real_stdout = $stdout

scenario_dirs.each do |dir|
  scenario_file = File.join(dir, 'scenario.rb')
  next unless File.exist?(scenario_file)

  name = File.basename(dir)
  Trakable::Context.reset!

  # Suppress output
  $stdout = File.open(File::NULL, 'w')

  GC.start
  GC.disable
  before = GC.stat[:total_allocated_objects]

  begin
    load scenario_file
    status = 'PASS'
  rescue StandardError => e
    status = "FAIL"
  end

  after = GC.stat[:total_allocated_objects]
  GC.enable

  $stdout.close
  $stdout = real_stdout

  results << { name: name, allocs: after - before, status: status }
end

$stdout = real_stdout

puts '=' * 70
puts 'Trakable Integration Memory Benchmark'
puts '=' * 70
puts

total = 0
results.each do |r|
  total += r[:allocs]
  flag = r[:status] == 'PASS' ? ' ' : 'F'
  printf "[%s] %-45s %7d allocs\n", flag, r[:name][0..44], r[:allocs]
end

puts '-' * 70
printf "    %-45s %7d allocs\n", "TOTAL (#{results.size} scenarios)", total
puts

gc = GC.stat
puts "GC runs: #{gc[:count]} | Live objects: #{gc[:heap_live_slots]}"
puts '=' * 70
