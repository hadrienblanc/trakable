# frozen_string_literal: true

require 'test_helper'

class Trakable::ConfigurationTest < Minitest::Test
  def setup
    @config = Trakable::Configuration.new
  end

  def test_enabled_defaults_to_true
    assert @config.enabled
  end

  def test_ignored_attrs_defaults_to_created_at_updated_at_and_id
    assert_equal %w[created_at updated_at id], @config.ignored_attrs
  end

  def test_whodunnit_method_defaults_to_current_user
    assert_equal :current_user, @config.whodunnit_method
  end

  def test_whodunnit_method_is_configurable
    @config.whodunnit_method = :current_admin

    assert_equal :current_admin, @config.whodunnit_method
  end
end
