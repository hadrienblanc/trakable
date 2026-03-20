# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Trakable do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Trakable::VERSION).not_to be_nil
    end

    it 'follows semver format' do
      expect(Trakable::VERSION).to match(/\A\d+\.\d+\.\d+(\w+)?\z/)
    end
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(described_class.configuration).to be_a(Trakable::Configuration)
    end

    it 'memoizes the configuration' do
      expect(described_class.configuration).to eq(described_class.configuration)
    end
  end

  describe '.configure' do
    after do
      # Reset to defaults
      described_class.configuration.enabled = true
      described_class.configuration.ignored_attrs = %w[created_at updated_at]
    end

    it 'yields the configuration' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.configuration)
    end

    it 'allows setting configuration options' do
      described_class.configure do |config|
        config.enabled = false
        config.ignored_attrs = %w[created_at]
      end

      expect(described_class.configuration.enabled).to be false
      expect(described_class.configuration.ignored_attrs).to eq(%w[created_at])
    end
  end

  describe '.enabled?' do
    it 'returns true by default' do
      expect(described_class.enabled?).to be true
    end

    it 'reflects configuration.enabled' do
      described_class.configuration.enabled = false
      expect(described_class.enabled?).to be false

      described_class.configuration.enabled = true
      expect(described_class.enabled?).to be true
    end
  end
end
