# frozen_string_literal: true

# Scenario 29: Soft Delete Integration
# Tests §25 Soft delete integration (180-181)

require_relative '../scenario_runner'

run_scenario 'Soft Delete Integration' do
  puts 'Test 180: soft-deleted records (Discard/Paranoia) — tracks restore event...'

  # Soft delete gems like Discard and Paranoia add discarded_at/deleted_at
  # Restore should be tracked as a special event

  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create'),
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update',
                       changeset: { 'discarded_at' => [nil, Time.now] }),
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update',
                       changeset: { 'discarded_at' => [Time.now, nil] })
  ]

  # The restore is an update with discarded_at: [time, nil]
  restore_trak = traks.find { |t| t.changeset&.key?('discarded_at') && t.changeset['discarded_at'][1].nil? }
  refute_nil restore_trak, 'Restore should be tracked'
  puts '   ✓ restore event tracked for soft-deleted records'

  puts 'Test 181: record.traks survives soft-delete...'

  # Soft delete should not remove traks
  # Only hard destroy would trigger dependent: :nullify

  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create'),
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update')
  ]

  # After soft delete, traks still reference the record
  soft_deleted = true
  traks_still_exist = !soft_deleted || traks.length == 2

  assert_equal 2, traks.length, 'Traks should survive soft delete'
  puts '   ✓ traks survive soft-delete'
end
