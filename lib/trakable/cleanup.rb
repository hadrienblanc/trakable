# frozen_string_literal: true

module Trakable
  # Cleanup handles retention and max_traks pruning for Trak records.
  #
  # Intended to run from background jobs, not synchronously.
  #
  # Usage:
  #   # Per-record cleanup
  #   Trakable::Cleanup.run(record)
  #
  #   # Bulk retention cleanup (in a cron/background job)
  #   Trakable::Cleanup.run_retention(Post)
  #   Trakable::Cleanup.run_retention(Post, batch_size: 5_000)
  #
  class Cleanup
    BATCH_SIZE = 1_000

    attr_reader :record

    def initialize(record)
      @record = record
    end

    # Run cleanup for a single record.
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
    # Deletes in batches to avoid locking the table on large datasets.
    #
    # @param model_class [Class] The model class to clean up
    # @param retention_period [Integer, nil] Override retention period in seconds
    # @param batch_size [Integer] Number of rows to delete per batch (default: 1_000)
    # @return [Integer, nil] Total number of deleted rows, or nil if no retention configured
    #
    def self.run_retention(model_class, retention_period: nil, batch_size: BATCH_SIZE)
      retention = retention_period || model_class.trakable_options[:retention]
      return nil unless retention

      trak_class = resolve_trak_class
      return 0 unless trak_class.respond_to?(:where)

      cutoff = Time.now - retention
      scope = trak_class.where(item_type: model_class.to_s)
                        .where(trak_class.arel_table[:created_at].lt(cutoff))

      delete_in_batches(scope, batch_size)
    end

    def self.resolve_trak_class
      Trakable::Trak
    end
    private_class_method :resolve_trak_class

    def self.delete_in_batches(scope, batch_size)
      total = 0
      loop do
        deleted = scope.limit(batch_size).delete_all
        total += deleted
        break if deleted < batch_size
      end
      total
    end
    private_class_method :delete_in_batches

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
