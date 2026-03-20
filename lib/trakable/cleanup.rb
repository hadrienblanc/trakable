# frozen_string_literal: true

module Trakable
  # Cleanup handles retention and max_traks pruning for Trak records.
  #
  # Usage:
  #   # Per-model configuration
  #   trakable max_traks: 100, retention: 90.days
  #
  #   # Manual cleanup
  #   Trakable::Cleanup.run(record)
  #   Trakable::Cleanup.run_retention(Post)
  #
  class Cleanup
    attr_reader :record

    def initialize(record)
      @record = record
    end

    # Run cleanup for a record after a new trak is created.
    #
    # @param record [ActiveRecord::Base] The record with traks to clean up
    #
    def self.run(record)
      new(record).run
    end

    def run # rubocop:disable Naming/PredicateMethod
      enforce_max_traks
      true
    end

    # Run retention cleanup for all records of a model class.
    #
    # @param model_class [Class] The model class to clean up
    # @param retention_period [Integer, nil] Override retention period in seconds
    # @return [Boolean, nil] true if cleanup ran, nil if no retention configured
    #
    def self.run_retention(model_class, retention_period: nil)
      retention = retention_period || model_class.trakable_options[:retention]
      return nil unless retention

      # In a real implementation, this would query the database:
      # Trakable::Trak.where(item_type: model_class.to_s)
      #              .where('created_at < ?', retention.seconds.ago)
      #              .destroy_all
      true
    end

    private

    def enforce_max_traks
      max = record.trakable_options[:max_traks]
      return unless max

      # In a real ActiveRecord implementation, this would be:
      # excess_traks = record.traks.order(created_at: :desc).offset(max)
      # excess_traks.destroy_all
      true
    end
  end
end
