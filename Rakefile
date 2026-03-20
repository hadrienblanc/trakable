# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.pattern = 'test/{trakable,generators}/**/*_test.rb'
end

Rake::TestTask.new(:test_integration) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.pattern = 'test/integration_test.rb'
end

task default: :test

require 'rubocop/rake_task'

RuboCop::RakeTask.new
