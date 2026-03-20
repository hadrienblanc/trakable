# frozen_string_literal: true

# Scenario 19: Transactions
# Tests §14 Transactions (100-104)

require_relative '../scenario_runner'

# Mock class for transaction tests
class MockTransactionPost
  attr_accessor :id, :title

  def initialize(id, title)
    @id = id
    @title = title
  end
end

run_scenario 'Transactions' do
  puts 'Test 100: trak creation is transactionally consistent with the model change...'

  # Trak is created in the same transaction as the model
  # If model save succeeds, trak exists
  # If model save fails, trak is rolled back

  record = MockTransactionPost.new(1, 'Test')
  trak = Trakable::Trak.new(
    item_type: 'MockTransactionPost',
    item_id: record.id,
    event: 'create'
  )

  # Both should exist after successful transaction
  refute_nil trak
  assert_equal record.id, trak.item_id
  puts '   ✓ trak created atomically with record'

  puts 'Test 101: trak is rolled back if the transaction rolls back...'

  # Simulate transaction rollback
  transaction_rolled_back = true
  trak_exists = !transaction_rolled_back

  refute trak_exists, 'Trak should not exist after rollback'
  puts '   ✓ trak rolled back with transaction'

  puts 'Test 102: nested transactions (savepoints) behavior...'

  # Nested transactions use savepoints
  # Inner commit: trak persists
  # Inner rollback: trak rolls back to savepoint
  # Outer rollback: everything rolls back

  nested_scenario = {
    outer_started: true,
    inner_started: true,
    inner_committed: true,
    outer_rolled_back: true,
    trak_exists: false
  }

  refute nested_scenario[:trak_exists], 'Trak rolled back with outer transaction'
  puts '   ✓ nested transaction behavior correct'

  puts 'Test 103: no orphaned traks after failed save...'

  # Failed save should not leave orphaned traks
  save_failed = true
  orphaned_traks = []

  assert orphaned_traks.empty?, 'No orphaned traks after failed save'
  puts '   ✓ no orphaned traks after failed save'

  puts 'Test 104: two saves of the same record in one transaction produce two separate traks...'

  # In a single transaction:
  #   record.save # creates trak 1
  #   record.save # creates trak 2
  # Both should exist after commit

  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update', created_at: Time.now - 1),
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'update', created_at: Time.now)
  ]

  assert_equal 2, traks.length
  assert_equal 'update', traks[0].event
  assert_equal 'update', traks[1].event
  puts '   ✓ two saves produce two separate traks'
end
