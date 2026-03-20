#!/usr/bin/env ruby
# frozen_string_literal: true

# Trakable Integration Test Runner
# Runs all scenario tests in order

puts '=' * 70
puts 'TRAKABLE INTEGRATION TESTS'
puts '=' * 70
puts

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'trakable'
require 'minitest/autorun'

# Reset context before tests
Trakable::Context.reset!

# Track results
results = { passed: 0, failed: 0, errors: [] }

# Run each scenario
scenarios_dir = File.expand_path('scenarios', __dir__)
scenario_dirs = Dir.glob("#{scenarios_dir}/*").select { |d| File.directory?(d) }.sort

scenario_dirs.each do |dir|
  scenario_file = File.join(dir, 'scenario.rb')
  next unless File.exist?(scenario_file)

  puts "\n#{'=' * 70}"
  puts "Running: #{File.basename(dir)}"
  puts '=' * 70

  begin
    load scenario_file
    results[:passed] += 1
  rescue StandardError => e
    results[:failed] += 1
    results[:errors] << { scenario: File.basename(dir), error: e.message }
  end

  # Reset context between scenarios
  Trakable::Context.reset!
end

# Summary
puts "\n#{'=' * 70}"
puts 'INTEGRATION TEST SUMMARY'
puts '=' * 70
puts "Passed: #{results[:passed]}"
puts "Failed: #{results[:failed]}"

if results[:errors].any?
  puts "\nFailures:"
  results[:errors].each do |error|
    puts "  - #{error[:scenario]}: #{error[:error]}"
  end
  exit 1
else
  puts "\nAll integration tests passed! ✓"
  exit 0
end
