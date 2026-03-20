# frozen_string_literal: true

require 'test_helper'

class Trakable::ContextTest < Minitest::Test
  def teardown
    reset_context!
  end

  # whodunnit
  def test_whodunnit_returns_nil_by_default
    assert_nil Trakable::Context.whodunnit
  end

  def test_whodunnit_can_be_set_and_retrieved
    user = Object.new
    Trakable::Context.whodunnit = user
    assert_equal user, Trakable::Context.whodunnit
  end

  def test_whodunnit_can_be_set_to_nil
    Trakable::Context.whodunnit = Object.new
    Trakable::Context.whodunnit = nil
    assert_nil Trakable::Context.whodunnit
  end

  # tracking_enabled?
  def test_tracking_enabled_returns_true_by_default_when_trakable_enabled
    assert Trakable::Context.tracking_enabled?
  end

  def test_tracking_enabled_returns_false_when_trakable_globally_disabled
    Trakable.configuration.enabled = false
    refute Trakable::Context.tracking_enabled?
    Trakable.configuration.enabled = true
  end

  def test_tracking_enabled_returns_false_when_explicitly_disabled
    Trakable::Context.tracking_enabled = false
    refute Trakable::Context.tracking_enabled?
  end

  def test_tracking_enabled_returns_true_when_explicitly_enabled
    Trakable.configuration.enabled = false
    Trakable::Context.tracking_enabled = true
    assert Trakable::Context.tracking_enabled?
    Trakable.configuration.enabled = true
  end

  # with_user
  def test_with_user_sets_whodunnit_within_block
    user = Object.new
    Trakable::Context.with_user(user) do
      assert_equal user, Trakable::Context.whodunnit
    end
  end

  def test_with_user_resets_whodunnit_after_block
    user = Object.new
    Trakable::Context.whodunnit = 'previous'
    Trakable::Context.with_user(user) do
      # nothing
    end
    assert_equal 'previous', Trakable::Context.whodunnit
  end

  def test_with_user_resets_whodunnit_even_when_block_raises
    user = Object.new
    Trakable::Context.whodunnit = 'previous'
    assert_raises(RuntimeError) do
      Trakable::Context.with_user(user) { raise 'error' }
    end
    assert_equal 'previous', Trakable::Context.whodunnit
  end

  def test_with_user_raises_argument_error_without_block
    user = Object.new
    assert_raises(ArgumentError) do
      Trakable::Context.with_user(user)
    end
  end

  def test_with_user_supports_nested_blocks
    user1 = Object.new
    user2 = Object.new

    Trakable::Context.with_user(user1) do
      assert_equal user1, Trakable::Context.whodunnit
      Trakable::Context.with_user(user2) do
        assert_equal user2, Trakable::Context.whodunnit
      end
      assert_equal user1, Trakable::Context.whodunnit
    end
  end

  def test_with_user_nil_clears_in_nested_scope
    user = Object.new

    Trakable::Context.with_user(user) do
      assert_equal user, Trakable::Context.whodunnit
      Trakable::Context.with_user(nil) do
        assert_nil Trakable::Context.whodunnit
      end
      assert_equal user, Trakable::Context.whodunnit
    end
  end

  # with_tracking
  def test_with_tracking_enables_tracking_within_block
    Trakable.configuration.enabled = false
    Trakable::Context.with_tracking do
      assert Trakable::Context.tracking_enabled?
    end
    Trakable.configuration.enabled = true
  end

  def test_with_tracking_resets_tracking_after_block
    Trakable.configuration.enabled = false
    Trakable::Context.with_tracking do
      # nothing
    end
    refute Trakable::Context.tracking_enabled?
    Trakable.configuration.enabled = true
  end

  def test_with_tracking_resets_tracking_even_when_block_raises
    Trakable.configuration.enabled = false
    assert_raises(RuntimeError) do
      Trakable::Context.with_tracking { raise 'error' }
    end
    refute Trakable::Context.tracking_enabled?
    Trakable.configuration.enabled = true
  end

  def test_with_tracking_raises_argument_error_without_block
    assert_raises(ArgumentError) do
      Trakable::Context.with_tracking
    end
  end

  # without_tracking
  def test_without_tracking_disables_tracking_within_block
    Trakable::Context.without_tracking do
      refute Trakable::Context.tracking_enabled?
    end
  end

  def test_without_tracking_resets_tracking_after_block
    Trakable::Context.without_tracking do
      # nothing
    end
    assert Trakable::Context.tracking_enabled?
  end

  def test_without_tracking_resets_tracking_even_when_block_raises
    assert_raises(RuntimeError) do
      Trakable::Context.without_tracking { raise 'error' }
    end
    assert Trakable::Context.tracking_enabled?
  end

  def test_without_tracking_raises_argument_error_without_block
    assert_raises(ArgumentError) do
      Trakable::Context.without_tracking
    end
  end

  def test_inner_without_tracking_wins_over_outer_with_tracking
    Trakable::Context.with_tracking do
      Trakable::Context.without_tracking do
        refute Trakable::Context.tracking_enabled?
      end
    end
  end

  # Thread safety
  def test_whodunnit_isolated_between_threads
    user1 = Object.new
    user2 = Object.new

    thread1 = Thread.new do
      Trakable::Context.with_user(user1) do
        sleep(0.05)
        assert_equal user1, Trakable::Context.whodunnit
      end
    end

    thread2 = Thread.new do
      Trakable::Context.with_user(user2) do
        sleep(0.01)
        assert_equal user2, Trakable::Context.whodunnit
      end
    end

    thread1.join
    thread2.join
  end

  def test_tracking_enabled_isolated_between_threads
    thread1 = Thread.new do
      Trakable::Context.with_tracking do
        sleep(0.05)
        assert Trakable::Context.tracking_enabled?
      end
    end

    thread2 = Thread.new do
      Trakable::Context.without_tracking do
        sleep(0.01)
        refute Trakable::Context.tracking_enabled?
      end
    end

    thread1.join
    thread2.join
  end

  # reset!
  def test_reset_clears_whodunnit
    Trakable::Context.whodunnit = Object.new
    Trakable::Context.reset!
    assert_nil Trakable::Context.whodunnit
  end

  def test_reset_clears_tracking_enabled_override
    Trakable::Context.tracking_enabled = false
    Trakable::Context.reset!
    assert Trakable::Context.tracking_enabled?
  end
end
