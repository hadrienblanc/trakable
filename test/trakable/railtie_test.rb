# frozen_string_literal: true

require 'test_helper'

class RailtieTest < Minitest::Test
  def test_railtie_file_exists
    railtie_path = File.expand_path('../../lib/trakable/railtie.rb', __dir__)

    assert File.exist?(railtie_path)
  end

  def test_railtie_source_has_expected_structure
    railtie_source = File.read(
      File.expand_path('../../lib/trakable/railtie.rb', __dir__)
    )

    assert_includes railtie_source, 'class Railtie'
    assert_includes railtie_source, 'generators do'
    assert_includes railtie_source, 'initializer'
    assert_includes railtie_source, 'trakable.configure'
    assert_includes railtie_source, 'trakable.controller'
    assert_includes railtie_source, 'action_controller_base'
    assert_includes railtie_source, 'Trakable::Controller'
  end

  def test_railtie_only_loads_in_rails
    # The railtie.rb should have the conditional load
    main_source = File.read(
      File.expand_path('../../lib/trakable.rb', __dir__)
    )

    assert_includes main_source, "require_relative 'trakable/railtie' if defined?(Rails::Railtie)"
  end
end
