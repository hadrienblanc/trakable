# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Trakable::Configuration do
  subject(:config) { described_class.new }

  describe '#enabled' do
    it 'defaults to true' do
      expect(config.enabled).to be true
    end
  end

  describe '#ignored_attrs' do
    it 'defaults to created_at and updated_at' do
      expect(config.ignored_attrs).to eq(%w[created_at updated_at])
    end
  end
end
