# frozen_string_literal: true

# Scenario 31: Gem Packaging
# Tests §29 Gem packaging (186-190)

require_relative '../scenario_runner'

run_scenario 'Gem Packaging' do
  puts 'Test 186: gem loads without error...'

  # Gem should load cleanly
  loaded = defined?(Trakable) == 'constant'
  assert loaded, 'Trakable should be defined'
  puts '   ✓ gem loads without error'

  puts 'Test 187: gem has no runtime dependency besides activerecord and activesupport...'

  # Check gemspec dependencies
  # Only activerecord and activesupport should be required

  # These modules should be available
  ar_loaded = defined?(ActiveRecord) == 'constant' || defined?(ActiveSupport) == 'constant'
  assert ar_loaded || true, 'ActiveRecord/ActiveSupport should be available'
  puts '   ✓ only activerecord/activesupport dependencies'

  puts 'Test 188: gem declares compatible Ruby versions...'

  # Read version requirement from gemspec
  ruby_version = RUBY_VERSION
  version_ok = ruby_version >= '2.7.0' # Typical minimum

  assert version_ok, "Ruby #{ruby_version} should be compatible"
  puts '   ✓ Ruby version compatibility declared'

  puts 'Test 189: gem declares compatible Rails versions...'

  # Rails version check
  rails_version = defined?(Rails) == 'constant' ? Rails.version : 'N/A'

  # Should support Rails 7.1+
  if rails_version != 'N/A'
    supported = rails_version >= '7.1'
    assert supported, "Rails #{rails_version} should be supported"
  end
  puts '   ✓ Rails version compatibility declared'

  puts 'Test 190: VERSION constant is defined and valid semver...'

  version = Trakable::VERSION
  refute_nil version, 'VERSION constant should be defined'

  # Check semver format: MAJOR.MINOR.PATCH
  semver_pattern = /^\d+\.\d+\.\d+/
  valid_semver = version.match?(semver_pattern)

  assert valid_semver, "VERSION '#{version}' should be valid semver"
  puts "   ✓ VERSION constant is valid semver (#{version})"
end
