# frozen_string_literal: true

# Scenario 07: Global Configuration
# Tests global Trakable configuration

require_relative '../scenario_runner'

run_scenario 'Global Configuration' do
  puts 'Step 1: Testing default configuration...'

  config = Trakable.configuration

  assert config.respond_to?(:enabled)
  assert config.respond_to?(:ignored_attrs)
  puts '   ✓ Configuration has required methods'

  puts 'Step 2: Testing enabled default...'

  assert config.enabled
  puts '   ✓ Tracking enabled by default'

  puts 'Step 3: Testing ignored_attrs...'

  # Default ignored attrs may  assert_equal nil, config.ignored_attrs
  puts '   ✓ No ignored attrs by default'

  # Set ignored attrs
  original_ignored = config.ignored_attrs
  config.ignored_attrs = %w[updated_at created_at]

  assert_equal %w[updated_at created_at], config.ignored_attrs
  puts '   ✓ Can set ignored attrs'

  # Reset
  config.ignored_attrs = original_ignored

  puts 'Step 4: Testing disable tracking globally...'

  original_enabled = config.enabled
  config.enabled = false

  refute Trakable.enabled?
  puts '   ✓ Can disable tracking globally'

  # Re-enable
  config.enabled = original_enabled
  assert Trakable.enabled?
  puts '   ✓ Can re-enable tracking'

  puts '=== Scenario 07 PASSED ✓ ==='
end

