# frozen_string_literal: true

require 'test_helper'

class TrakableTest < Minitest::Test
  def teardown
    reset_context!
    Trakable.configuration.enabled = true
  end

  # configuration
  def test_configuration_returns_configuration_instance
    assert_instance_of Trakable::Configuration, Trakable.configuration
  end

  def test_configure_yields_configuration
    Trakable.configure do |config|
      config.enabled = false
    end
    refute Trakable.configuration.enabled
    Trakable.configuration.enabled = true
  end

  def test_enabled_returns_configuration_enabled
    assert Trakable.enabled?

    Trakable.configuration.enabled = false
    refute Trakable.enabled?

    Trakable.configuration.enabled = true
    assert Trakable.enabled?
  end

  # with_user
  def test_with_user_delegates_to_context
    user = Object.new
    Trakable.with_user(user) do
      assert_equal user, Trakable::Context.whodunnit
    end
  end

  # with_tracking
  def test_with_tracking_enables_tracking_within_block
    Trakable.configuration.enabled = false
    Trakable.with_tracking do
      assert Trakable::Context.tracking_enabled?
    end
    Trakable.configuration.enabled = true
  end

  def test_with_tracking_resets_after_block
    Trakable.configuration.enabled = false
    Trakable.with_tracking { nil }
    refute Trakable::Context.tracking_enabled?
    Trakable.configuration.enabled = true
  end

  def test_with_tracking_resets_to_previous_state_when_nested
    # First, set tracking to true
    Trakable::Context.tracking_enabled = true

    Trakable.with_tracking do
      # Within block, tracking should be true
      assert Trakable::Context.tracking_enabled?

      # Disable within nested context
      Trakable::Context.tracking_enabled = false

      Trakable.with_tracking do
        # Should be true again
        assert Trakable::Context.tracking_enabled?
      end

      # After nested block, should be back to false (previous state)
      refute Trakable::Context.tracking_enabled?
    end

    # Should still be true after outer block (previous state was true)
    assert Trakable::Context.tracking_enabled?
  end

  # without_tracking
  def test_without_tracking_delegates_to_context
    Trakable.without_tracking do
      refute Trakable::Context.tracking_enabled?
    end
  end

  def test_without_tracking_resets_to_previous_state_when_nested
    # Start with tracking enabled
    Trakable::Context.tracking_enabled = true

    Trakable.without_tracking do
      refute Trakable::Context.tracking_enabled?

      # Nested without_tracking
      Trakable.without_tracking do
        refute Trakable::Context.tracking_enabled?
      end

      # After nested block, still false
      refute Trakable::Context.tracking_enabled?
    end

    # After outer block, should be back to true
    assert Trakable::Context.tracking_enabled?
  end
end
