# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/trakable/controller'

class ControllerTest < Minitest::Test
  def setup
    Trakable::Context.reset!
    @controller = MockController.new
  end

  def teardown
    Trakable::Context.reset!
  end

  def test_controller_includes_around_action
    assert MockController.respond_to?(:around_action)
  end

  def test_default_whodunnit_method_is_current_user
    assert_equal :current_user, MockController.trakable_whodunnit_method
  end

  def test_sets_whodunnit_from_current_user
    user = MockUser.new(1)
    @controller.current_user = user

    @controller.perform_action do
      assert_equal user, Trakable::Context.whodunnit
    end
  end

  def test_resets_whodunnit_after_action
    user = MockUser.new(1)
    @controller.current_user = user

    @controller.perform_action { nil }

    assert_nil Trakable::Context.whodunnit
  end

  def test_works_with_nil_user
    @controller.current_user = nil

    @controller.perform_action do
      assert_nil Trakable::Context.whodunnit
    end
  end

  def test_custom_whodunnit_method
    custom_controller = MockCustomController.new
    admin = MockUser.new(99)
    custom_controller.current_admin = admin

    custom_controller.perform_action do
      assert_equal admin, Trakable::Context.whodunnit
    end
  end

  def test_resets_whodunnit_on_exception
    user = MockUser.new(1)
    @controller.current_user = user

    begin
      @controller.perform_action { raise 'Test error' }
    rescue StandardError
      # Expected
    end

    assert_nil Trakable::Context.whodunnit
  end

  def test_nested_controllers_reset_correctly
    user1 = MockUser.new(1)
    user2 = MockUser.new(2)

    @controller.current_user = user1

    @controller.perform_action do
      assert_equal user1, Trakable::Context.whodunnit

      Trakable::Context.whodunnit = user2
      assert_equal user2, Trakable::Context.whodunnit
    end

    assert_nil Trakable::Context.whodunnit
  end
end

# Mock classes for testing
class MockUser
  attr_reader :id

  def initialize(id)
    @id = id
  end
end

class MockController
  include Trakable::Controller

  attr_accessor :current_user

  def self.around_action(_method_name)
    # Stub - in real Rails, this registers the callback
  end

  def perform_action(&)
    set_trakable_whodunnit(&)
  end
end

class MockCustomController
  attr_accessor :current_admin

  # Manually include concern behavior
  def self.trakable_whodunnit_method
    :current_admin
  end

  def self.around_action(_method_name)
    # Stub
  end

  def perform_action(&)
    set_trakable_whodunnit(&)
  end

  private

  def set_trakable_whodunnit(&)
    user = send(self.class.trakable_whodunnit_method)
    Trakable.with_user(user, &)
  end
end
