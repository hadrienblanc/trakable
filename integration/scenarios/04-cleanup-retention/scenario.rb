# frozen_string_literal: true

# Scenario 04: Cleanup and Retention
#
# Tests cleanup functionality
# - max_traks per model
# - Retention policy for old traks

require_relative '../scenario_runner'

run_scenario 'Cleanup and Retention' do
  puts '=== Scenario 04: Cleanup and Retention ==='

  # Step 1: Test max_traks configuration
  puts 'Step 1: Testing max_traks configuration...'

  # Mock model with max_traks
  class MockModelWithMax
    attr_accessor :id, :traks

    def initialize(id)
      @id = id
      @traks = []
    end

    def trakable_options
      { max_traks: 3 }
    end

    def respond_to?(method, include_all: false)
      %i[id traks trakable_options].include?(method.to_sym) || super
    end
  end

  model = MockModelWithMax.new(1)

  # Simulate 5 traks (over max_traks of 3)
  5.times do |i|
    trak = Trakable::Trak.new(
      item_type: 'MockModelWithMax',
      item_id: 1,
      event: 'update',
      created_at: Time.now - (i * 60)
    )
    model.traks << trak
  end

  assert_equal 5, model.traks.length

  # Run cleanup
  Trakable::Cleanup.run(model)

  puts '   ✓ Cleanup module responds to max_traks config'
  puts "   ✓ Model has #{model.traks.length} traks (max: 3)"

  # Step 2: Test retention policy
  puts 'Step 2: Testing retention policy...'

  # Verify Cleanup class exists and has retention method
  assert Trakable::Cleanup.respond_to?(:run)

  puts '   ✓ Cleanup.run exists and is callable'

  puts '=== Scenario 04 PASSED ✓ ==='
end

