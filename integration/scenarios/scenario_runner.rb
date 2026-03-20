# frozen_string_literal: true

require_relative '../../test/test_helper'
require 'securerandom'
require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/numeric/time'

# Scenario runner helper
# Include this in your scenario files

def run_scenario(name)
  puts "\n#{'=' * 60}"
  puts "SCENARIO: #{name}"
  puts '=' * 60
  yield
  puts "\n#{'=' * 60}"
  puts "SCENARIO #{name} COMPLETE"
  puts '=' * 60
rescue StandardError => e
  puts "\n#{'!' * 60}"
  puts "SCENARIO FAILED: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  puts '!' * 60
  raise e
end

def assert(condition, message = 'Assertion failed')
  raise message unless condition
end

def assert_equal(expected, actual, message = nil)
  msg = message || "Expected #{expected.inspect}, got #{actual.inspect}"
  raise msg unless expected == actual
end

def assert_kind_of(klass, obj)
  raise "Expected #{klass}, got #{obj.class}" unless obj.is_a?(klass)
end

def assert_includes(collection, item)
  raise "Expected #{collection.inspect} to include #{item.inspect}" unless collection.include?(item)
end

def assert_nil(obj)
  raise "Expected nil, got #{obj.inspect}" unless obj.nil?
end

def refute(condition, message = 'Expected condition to be false')
  raise message if condition
end

def refute_nil(obj, message = 'Expected non-nil value')
  raise message if obj.nil?
end

def refute_equal(expected, actual)
  raise "Expected #{actual.inspect} to not equal #{expected.inspect}" if expected == actual
end

# Refute helper (alias for refute)
def refute(condition, message = 'Expected condition to be false')
  raise message if condition
end

# Assert with message
def assert_with_message(condition, message = 'Assertion failed')
  raise message unless condition
end
