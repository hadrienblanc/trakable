# frozen_string_literal: true

# Scenario 01: Basic CRUD Tracking
# Tests that Trakable correctly tracks create, update, destroy events

require_relative '../scenario_runner'

run_scenario 'Basic CRUD Tracking' do
  puts 'Step 1: Testing Context defaults...'

  # Context should be available
  assert Trakable::Context.respond_to?(:whodunnit)
  assert Trakable::Context.respond_to?(:tracking_enabled?)
  puts '   ✓ Context has required methods'

  puts 'Step 2: Testing tracking enabled by default...'
  assert Trakable::Context.tracking_enabled?
  puts '   ✓ Tracking enabled by default'

  puts 'Step 3: Testing Trak model...'

  # Create a Trak
  trak = Trakable::Trak.new(
    item_type: 'Post',
    item_id: 1,
    event: 'update',
    object: { 'title' => 'Old Title' },
    changeset: { 'title' => %w[Old New] }
  )

  assert_equal 'update', trak.event
  assert_equal({ 'title' => %w[Old New] }, trak.changeset)
  puts '   ✓ Trak stores event, object, changeset'

  puts 'Step 4: Testing event type helpers...'

  assert trak.update?
  refute trak.create?
  refute trak.destroy?
  puts '   ✓ Event type helpers work correctly'

  puts 'Step 5: Testing Context with_user...'
  user = 'TestUser'

  Trakable::Context.with_user(user) do
    assert_equal user, Trakable::Context.whodunnit
  end

  assert_equal nil, Trakable::Context.whodunnit
  puts '   ✓ with_user sets and resets whodunnit'
end
