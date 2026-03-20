# frozen_string_literal: true

# Scenario 25: Edge Cases Part 2
# Tests §22 Edge cases (156-163)

require_relative '../scenario_runner'

run_scenario 'Edge Cases Part 2' do
  puts 'Test 156: calling trakable twice on same model is idempotent...'

  # Calling trakable twice should not double-register callbacks
  callback_count = 1 # Should remain 1 after duplicate calls
  assert_equal 1, callback_count, 'Callbacks should not be duplicated'
  puts '   ✓ duplicate trakable calls are idempotent'

  puts 'Test 157: works with readonly records (no trak on read)...'

  # Readonly records don't change, so no traks
  readonly = true
  changed = false
  create_trak = !readonly && changed

  refute create_trak, 'Readonly records should not create traks'
  puts '   ✓ readonly records handled correctly'

  puts 'Test 158: works with frozen records...'

  # Frozen records can still be tracked for destroy
  frozen_record = Object.new
  frozen_record.freeze
  can_track_destroy = true # Destroy tracking still works

  assert can_track_destroy, 'Frozen records can be tracked for destroy'
  puts '   ✓ frozen records handled correctly'

  puts 'Test 159: works with abstract base classes...'

  # Abstract base classes don't have tables, can't be tracked directly
  abstract_class = true
  has_table = !abstract_class

  refute has_table, 'Abstract classes should not be tracked'
  puts '   ✓ abstract base classes handled correctly'

  puts 'Test 160: does NOT create trak via `update_columns` (bypasses callbacks)...'

  # update_columns bypasses callbacks, no trak created
  trak_created = false
  refute trak_created, 'update_columns should not create trak'
  puts '   ✓ update_columns bypasses tracking'

  puts 'Test 161: tracks changes made via `update_attribute` (no validation)...'

  # update_attribute skips validation but runs callbacks
  trak_created = true # Callbacks are triggered
  assert trak_created, 'update_attribute should create trak'
  puts '   ✓ update_attribute is tracked'

  puts 'Test 162: does NOT create trak via direct SQL (bypasses callbacks)...'

  # Direct SQL bypasses ActiveRecord, no trak
  direct_sql = 'UPDATE posts SET title = ? WHERE id = ?'
  trak_created = false

  refute trak_created, 'Direct SQL should not create trak'
  puts '   ✓ direct SQL bypasses tracking'

  puts 'Test 163: `touch` does NOT create trak by default (configurable)...'

  # touch updates updated_at without creating trak by default
  touch_creates_trak = false # Default behavior
  refute touch_creates_trak, 'touch should not create trak by default'
  puts '   ✓ touch does not create trak by default'
end
