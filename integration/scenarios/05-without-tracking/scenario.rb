# frozen_string_literal: true

# Scenario 05: Without Tracking
#
# Tests skipping tracking functionality
# - without_tracking helper
# - Nested tracking control

require_relative '../scenario_runner'

run_scenario 'Without Tracking' do
  puts '=== Scenario 05: Without Tracking ==='

  # Step 1: Test without_tracking
  puts 'Step 1: Testing without_tracking helper...'

  # Initially enabled
  assert Trakable::Context.tracking_enabled?
  puts '   ✓ Tracking enabled by default'

  # Disabled within block
  Trakable.without_tracking do
    refute Trakable::Context.tracking_enabled?
    puts '   ✓ Tracking disabled within block'
  end

  # Re-enabled after block
  assert Trakable::Context.tracking_enabled?
  puts '   ✓ Tracking re-enabled after block'

  # Step 2: Test nested without_tracking
  puts 'Step 2: Testing nested tracking control...'

  Trakable.without_tracking do
    refute Trakable::Context.tracking_enabled?

    # with_tracking inside without_tracking
    Trakable.with_tracking do
      assert Trakable::Context.tracking_enabled?
    end

    refute Trakable::Context.tracking_enabled?
    puts '   ✓ Nested tracking control works'
  end

  # Step 3: Test exception handling
  puts 'Step 3: Testing exception handling...'

  begin
    Trakable.without_tracking do
      raise 'Test error'
    end
  rescue RuntimeError
    # Expected
  end

  assert Trakable::Context.tracking_enabled?
  puts '   ✓ Tracking restored after exception'

  puts '=== Scenario 05 PASSED ✓ ==='
end

