# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Trakable::Context do
  after do
    described_class.reset!
  end

  describe '.whodunnit' do
    it 'returns nil by default' do
      expect(described_class.whodunnit).to be_nil
    end

    it 'can be set and retrieved' do
      user = double('User', id: 1)
      described_class.whodunnit = user
      expect(described_class.whodunnit).to eq(user)
    end
  end

  describe '.whodunnit=' do
    it 'sets the whodunnit value' do
      user = double('User', id: 1)
      described_class.whodunnit = user
      expect(described_class.whodunnit).to eq(user)
    end

    it 'can be set to nil' do
      described_class.whodunnit = double('User')
      described_class.whodunnit = nil
      expect(described_class.whodunnit).to be_nil
    end
  end

  describe '.tracking_enabled?' do
    it 'returns true by default when Trakable is enabled' do
      expect(described_class.tracking_enabled?).to be true
    end

    it 'returns false when Trakable is globally disabled' do
      Trakable.configuration.enabled = false
      expect(described_class.tracking_enabled?).to be false
      Trakable.configuration.enabled = true
    end

    it 'returns false when explicitly disabled via context' do
      described_class.tracking_enabled = false
      expect(described_class.tracking_enabled?).to be false
    end

    it 'returns true when explicitly enabled via context' do
      Trakable.configuration.enabled = false
      described_class.tracking_enabled = true
      expect(described_class.tracking_enabled?).to be true
      Trakable.configuration.enabled = true
    end
  end

  describe '.with_user' do
    it 'sets whodunnit within the block' do
      user = double('User', id: 1)
      described_class.with_user(user) do
        expect(described_class.whodunnit).to eq(user)
      end
    end

    it 'resets whodunnit after the block' do
      user = double('User', id: 1)
      described_class.whodunnit = 'previous'
      described_class.with_user(user) do
        # nothing
      end
      expect(described_class.whodunnit).to eq('previous')
    end

    it 'resets whodunnit even when block raises' do
      user = double('User', id: 1)
      described_class.whodunnit = 'previous'
      expect do
        described_class.with_user(user) { raise 'error' }
      end.to raise_error('error')
      expect(described_class.whodunnit).to eq('previous')
    end

    it 'raises ArgumentError without a block' do
      user = double('User', id: 1)
      expect do
        described_class.with_user(user)
      end.to raise_error(ArgumentError, 'with_user requires a block')
    end

    it 'supports nested blocks with innermost winning' do
      user1 = double('User', id: 1)
      user2 = double('User', id: 2)

      described_class.with_user(user1) do
        expect(described_class.whodunnit).to eq(user1)
        described_class.with_user(user2) do
          expect(described_class.whodunnit).to eq(user2)
        end
        expect(described_class.whodunnit).to eq(user1)
      end
    end

    it 'supports with_user(nil) to clear in nested scope' do
      user = double('User', id: 1)

      described_class.with_user(user) do
        expect(described_class.whodunnit).to eq(user)
        described_class.with_user(nil) do
          expect(described_class.whodunnit).to be_nil
        end
        expect(described_class.whodunnit).to eq(user)
      end
    end
  end

  describe '.with_tracking' do
    before do
      Trakable.configuration.enabled = false
    end

    after do
      Trakable.configuration.enabled = true
    end

    it 'enables tracking within the block' do
      described_class.with_tracking do
        expect(described_class.tracking_enabled?).to be true
      end
    end

    it 'resets tracking after the block' do
      described_class.with_tracking do
        # nothing
      end
      expect(described_class.tracking_enabled?).to be false
    end

    it 'resets tracking even when block raises' do
      expect do
        described_class.with_tracking { raise 'error' }
      end.to raise_error('error')
      expect(described_class.tracking_enabled?).to be false
    end

    it 'raises ArgumentError without a block' do
      expect do
        described_class.with_tracking
      end.to raise_error(ArgumentError, 'with_tracking requires a block')
    end
  end

  describe '.without_tracking' do
    it 'disables tracking within the block' do
      described_class.without_tracking do
        expect(described_class.tracking_enabled?).to be false
      end
    end

    it 'resets tracking after the block' do
      described_class.without_tracking do
        # nothing
      end
      expect(described_class.tracking_enabled?).to be true
    end

    it 'resets tracking even when block raises' do
      expect do
        described_class.without_tracking { raise 'error' }
      end.to raise_error('error')
      expect(described_class.tracking_enabled?).to be true
    end

    it 'raises ArgumentError without a block' do
      expect do
        described_class.without_tracking
      end.to raise_error(ArgumentError, 'without_tracking requires a block')
    end

    it 'inner without_tracking wins over outer with_tracking' do
      described_class.with_tracking do
        described_class.without_tracking do
          expect(described_class.tracking_enabled?).to be false
        end
      end
    end
  end

  describe 'thread safety' do
    it 'isolates whodunnit between threads' do
      user1 = double('User', id: 1)
      user2 = double('User', id: 2)

      thread1 = Thread.new do
        described_class.with_user(user1) do
          sleep(0.05)
          expect(described_class.whodunnit).to eq(user1)
        end
      end

      thread2 = Thread.new do
        described_class.with_user(user2) do
          sleep(0.01)
          expect(described_class.whodunnit).to eq(user2)
        end
      end

      thread1.join
      thread2.join
    end

    it 'isolates tracking_enabled between threads' do
      thread1 = Thread.new do
        described_class.with_tracking do
          sleep(0.05)
          expect(described_class.tracking_enabled?).to be true
        end
      end

      thread2 = Thread.new do
        described_class.without_tracking do
          sleep(0.01)
          expect(described_class.tracking_enabled?).to be false
        end
      end

      thread1.join
      thread2.join
    end
  end

  describe '.reset!' do
    it 'clears whodunnit' do
      described_class.whodunnit = double('User')
      described_class.reset!
      expect(described_class.whodunnit).to be_nil
    end

    it 'clears tracking_enabled override' do
      described_class.tracking_enabled = false
      described_class.reset!
      expect(described_class.tracking_enabled?).to be true
    end
  end
end
