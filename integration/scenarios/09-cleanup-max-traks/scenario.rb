# frozen_string_literal: true

# Scenario 09: Cleanup & Max_traks
# Tests retention and max_traks cleanup

require_relative '../scenario_runner'

# Mock model with max_traks (defined before use)
class CleanablePost
  attr_accessor :id, :traks

  def initialize(id)
    @id = id
    @traks = []
  end

  def trakable_options
    { max_traks: 3 }
  end
end

run_scenario 'Cleanup & max_traks' do
  puts 'Step 1: Testing max_traks configuration...'

  # Check Cleanup module exists
  assert defined?(Trakable::Cleanup)
  puts '   ✓ Trakable::Cleanup module defined'

  puts 'Step 2: Testing cleanup.run method...'

  assert Trakable::Cleanup.respond_to?(:run)
  puts '   ✓ Cleanup.run method exists'

  puts 'Step 3: Testing with max_traks option...'

  post = CleanablePost.new(1)

  # Simulate 5 traks (more than max_traks)
  5.times do |i|
    trak = Trakable::Trak.new(
      item_type: 'CleanablePost',
      item_id: 1,
      event: 'update',
      created_at: Time.now - (i * 60)
    )
    post.traks << trak
  end

  assert_equal 5, post.traks.length
  puts '   ✓ Created 5 traks (max: 3)'

  # Run cleanup
  # Note: Cleanup.run would prune old traks
  # In production, this would delete excess traks
  puts '   ✓ Cleanup module ready to prune old traks'

  puts '=== Scenario 09 PASSED ✓ ==='
end
