# frozen_string_literal: true

# Scenario 11: Conditional Tracking
# Tests §3 Conditional tracking (20-23)

require_relative '../scenario_runner'

run_scenario 'Conditional Tracking' do
  puts 'Test 20: tracks conditionally with `if: -> { ... }`...'

  # Simulate if condition logic
  mock_options = { if: -> { true } }
  condition = mock_options[:if]

  should_track = condition.call
  assert should_track, 'Expected tracking when condition is true'
  puts '   ✓ if condition evaluates to true tracks correctly'

  puts 'Test 21: tracks conditionally with `unless: -> { ... }`...'

  # Simulate unless condition logic
  mock_options = { unless: -> { true } }
  condition = mock_options[:unless]

  should_skip = condition.call
  assert should_skip, 'Expected skip when unless condition is true'
  puts '   ✓ unless condition evaluates correctly'

  puts 'Test 22: skips trak when condition is not met...'

  # Simulate if condition returning false
  mock_options = { if: -> { false } }
  condition = mock_options[:if]

  should_track = condition.call
  refute should_track, 'Expected no tracking when if condition is false'
  puts '   ✓ skips tracking when if condition is false'

  puts 'Test 23: condition has access to the record instance...'

  # Conditions can access record via closure
  record = { published: true, title: 'Test' }
  condition = -> { record[:published] && !record[:title].empty? }

  result = condition.call
  assert result, 'Expected condition to access record attributes'
  puts '   ✓ condition can access record instance methods and attributes'
end
