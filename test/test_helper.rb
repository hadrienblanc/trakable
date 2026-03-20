# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_group 'Library', 'lib'
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'trakable'
require 'minitest/autorun'

module Trakable
  module TestHelpers
    def reset_context!
      Trakable::Context.reset!
    end
  end
end

Minitest::Test.include(Trakable::TestHelpers)
