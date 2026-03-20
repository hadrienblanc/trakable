# frozen_string_literal: true

require 'test_helper'

class TrakableTest < Minitest::Test
  def teardown
    reset_context!
    Trakable.configuration.enabled = true
    Trakable.configuration.ignored_attrs = %w[created_at updated_at]
  end

  # VERSION
  def test_has_version_number
    refute_nil Trakable::VERSION
  end

  def test_version_follows_semver_format
    assert_match(/\A\d+\.\d+\.\d+(\w+)?\z/, Trakable::VERSION)
  end

  # Configuration
  def test_configuration_returns_configuration_instance
    assert_instance_of Trakable::Configuration, Trakable.configuration
  end

  def test_configuration_is_memoized
    assert_equal Trakable.configuration, Trakable.configuration
  end

  def test_configure_yields_configuration
    yielded = nil
    Trakable.configure { |config| yielded = config }
    assert_equal Trakable.configuration, yielded
  end

  def test_configure_allows_setting_options
    Trakable.configure do |config|
      config.enabled = false
      config.ignored_attrs = %w[created_at]
    end

    refute Trakable.configuration.enabled
    assert_equal %w[created_at], Trakable.configuration.ignored_attrs
  end

  # enabled?
  def test_enabled_returns_true_by_default
    assert Trakable.enabled?
  end

  def test_enabled_reflects_configuration
    Trakable.configuration.enabled = false
    refute Trakable.enabled?

    Trakable.configuration.enabled = true
    assert Trakable.enabled?
  end
end
