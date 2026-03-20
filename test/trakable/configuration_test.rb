# frozen_string_literal: true

require 'test_helper'

class Trakable::ConfigurationTest < Minitest::Test
  def setup
    @config = Trakable::Configuration.new
  end

  def test_enabled_defaults_to_true
    assert @config.enabled
  end

  def test_ignored_attrs_defaults_to_created_at_and_updated_at
    assert_equal %w[created_at updated_at], @config.ignored_attrs
  end
end
