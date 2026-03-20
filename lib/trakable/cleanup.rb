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

      trak_class = resolve_trak_class
      return true unless trak_class.respond_to?(:where)

      cutoff = Time.now - retention
      trak_class.where(item_type: model_class.to_s)
                .where('created_at < ?', cutoff)
                .delete_all
      true
    end

    # Resolve the Trak class — host app's AR model if available, fallback to gem's PORO
    def self.resolve_trak_class
      Object.const_defined?(:Trak) ? Object.const_get(:Trak) : Trakable::Trak
    end
    private_class_method :resolve_trak_class

    private

    def enforce_max_traks
      max = record.trakable_options[:max_traks]
      return unless max
      return unless record.respond_to?(:traks)

      traks = record.traks
      return unless traks.respond_to?(:where)

      traks.order(created_at: :desc).offset(max).delete_all
    end
  end
end
