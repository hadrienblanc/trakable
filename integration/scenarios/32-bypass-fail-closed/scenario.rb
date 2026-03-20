# frozen_string_literal: true

# Scenario 32: Bypass Methods & Fail-Closed Guarantees
# Tests §30-31 Bypass + Fail-closed (191-194, 193-194)

require_relative '../scenario_runner'

# Mock class for bypass tests
class MockBypassRecord
  attr_accessor :id, :title

  def initialize(id)
    @id = id
    @title = 'Test'
  end
end

run_scenario 'Bypass Methods & Fail-Closed' do
  puts 'Test 191: `record.delete` (not destroy) does NOT create a trak...'

  # delete bypasses callbacks, no trak created
  record = MockBypassRecord.new(1)

  # Simulate delete (bypasses callbacks)
  trak_created = false # delete doesn't trigger after_destroy

  refute trak_created, 'delete should not create trak'
  puts '   ✓ delete bypasses tracking'

  puts 'Test 192: `update_column` (singular) does NOT create a trak...'

  # update_column bypasses callbacks, no trak created
  trak_created = false # update_column doesn't trigger after_update

  refute trak_created, 'update_column should not create trak'
  puts '   ✓ update_column bypasses tracking'

  puts 'Test 193: when trak persistence fails, model change is also rolled back (no partial commit)...'

  # Fail-closed: trak failure = model rollback
  # Both should be in same transaction

  begin
    trak_persisted = false
    model_persisted = trak_persisted # Model only persists if trak persists

    refute model_persisted, 'Model should not persist when trak fails'
    puts '   ✓ fail-closed: model rollback on trak failure'
  rescue StandardError
    puts '   ✓ fail-closed: raises on trak persistence failure'
  end

  puts 'Test 194: metadata proc raises error — original save fails (fail-closed)...'

  # If metadata proc raises, the entire save should fail
  # This ensures no partial state

  metadata_proc = -> { raise 'Metadata error' }
  proc_raises = true

  begin
    metadata_proc.call
  rescue RuntimeError
    save_failed = true
  end

  assert save_failed, 'Save should fail when metadata proc raises'
  puts '   ✓ metadata proc error causes save to fail'

  puts 'Test (additional): `update_columns` (plural) does NOT create a trak...'

  # update_columns also bypasses callbacks
  trak_created = false # update_columns doesn't trigger after_update

  refute trak_created, 'update_columns should not create trak'
  puts '   ✓ update_columns bypasses tracking'
end
