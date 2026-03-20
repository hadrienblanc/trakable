# frozen_string_literal: true

# Scenario 03: Whodunnit Tracking
# Tests polymorphic whodunnit and thread-safe context

require_relative '../scenario_runner'

# Mock user class (defined before use)
class MockUser
  attr_reader :id

  def initialize(id)
    @id = id
  end
end

run_scenario 'Whodunnit Tracking' do
  puts 'Step 1: Testing whodunnit default...'

  assert_equal nil, Trakable::Context.whodunnit
  puts '   ✓ whodunnit is nil by default'

  puts 'Step 2: Testing with_user helper...'

  user = MockUser.new(42)

  Trakable::Context.with_user(user) do
    assert_equal user, Trakable::Context.whodunnit
  end

  assert_equal nil, Trakable::Context.whodunnit
  puts '   ✓ with_user sets and resets whodunnit'

  puts 'Step 3: Testing nested with_user...'

  user1 = MockUser.new(1)
  user2 = MockUser.new(2)

  Trakable::Context.with_user(user1) do
    assert_equal user1, Trakable::Context.whodunnit

    Trakable::Context.with_user(user2) do
      assert_equal user2, Trakable::Context.whodunnit
    end

    assert_equal user1, Trakable::Context.whodunnit
  end

  puts '   ✓ Nested with_user works correctly'

  puts 'Step 4: Testing exception handling...'

  begin
    Trakable::Context.with_user(user) do
      raise 'Test error'
    end
  rescue RuntimeError
    # Expected
  end

  assert_equal nil, Trakable::Context.whodunnit
  puts '   ✓ whodunnit reset after exception'

  puts 'Step 5: Testing metadata...'

  Trakable::Context.metadata = { 'ip' => '127.0.0.1' }
  assert_equal({ 'ip' => '127.0.0.1' }, Trakable::Context.metadata)

  Trakable::Context.reset!
  assert_equal nil, Trakable::Context.metadata
  puts '   ✓ metadata works and resets'
end
