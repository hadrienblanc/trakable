# frozen_string_literal: true

require_relative 'lib/trakable/version'

Gem::Specification.new do |spec|
  spec.name = 'trakable'
  spec.version = Trakable::VERSION
  spec.authors = ['Hadrien Blanc']
  spec.email = ['hadrien.blanc@example.com']

  spec.summary = 'Audit and versioning for ActiveRecord models'
  spec.description = 'Trakable provides audit logging and version tracking for ActiveRecord models with polymorphic whodunnit, changesets, and built-in retention'
  spec.homepage = 'https://github.com/hadrienblanc/trakable'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be included in the gem
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 7.1', '< 8.2'
  spec.add_dependency 'activesupport', '>= 7.1', '< 8.2'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rspec-rails', '~> 7.0'
  spec.add_development_dependency 'rubocop', '~> 1.69'
  spec.add_development_dependency 'rubocop-rails', '~> 2.27'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.3'
  spec.add_development_dependency 'sqlite3', '~> 2.5'
end
