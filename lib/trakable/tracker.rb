# frozen_string_literal: true

module Trakable
  # Tracker is responsible for building Trak records from ActiveRecord callbacks.
  #
  # Usage:
  #   Trakable::Tracker.call(record, 'create')
  #   Trakable::Tracker.call(record, 'update')
  #   Trakable::Tracker.call(record, 'destroy')
  #
  class Tracker
    attr_reader :record, :event

    def initialize(record, event)
      @record = record
      @event = event.to_s
    end

    # Entry point: build a Trak for the given record/event
    def self.call(record, event)
      new(record, event).call
    end

    def call
      return unless tracking_enabled?
      return if skip?

      build_trak
    end

    private

    def tracking_enabled?
      return false unless Trakable.enabled?

      Context.tracking_enabled?
    end

    def skip?
      return false unless trakable_record?

      skip_if_condition? || skip_unless_condition?
    end

    def trakable_record?
      return @trakable_record if defined?(@trakable_record)

      @trakable_record = record.respond_to?(:trakable_options)
    end

    def skip_if_condition?
      condition = record.trakable_options[:if]
      condition && !record.instance_eval(&condition)
    end

    def skip_unless_condition?
      condition = record.trakable_options[:unless]
      condition && record.instance_eval(&condition)
    end

    def build_trak
      trak = Trak.build(
        item: record,
        event: event,
        changeset: changeset,
        object: object_state,
        whodunnit: whodunnit,
        metadata: metadata
      )
      trak.save! if defined?(ActiveRecord::Base) && trak.is_a?(ActiveRecord::Base)
      trak
    end

    def object_state
      case event
      when 'create'
        nil
      when 'update'
        build_object_from_previous
      else
        record.attributes.except('id')
      end
    end

    def changeset
      return {} if event == 'destroy'

      filter_changeset(record.previous_changes)
    end

    def filter_changeset(changes)
      return {} if changes.empty?

      result = apply_only_filter(changes)
      apply_ignore_filter(result)
    end

    def apply_only_filter(changes)
      return changes unless trakable_record?

      only = record.trakable_options[:only]
      return changes unless only

      changes.slice(*only)
    end

    def apply_ignore_filter(changes)
      ignore = []
      if trakable_record?
        record_ignore = record.trakable_options[:ignore]
        ignore.concat(record_ignore) if record_ignore
      end
      global = Trakable.configuration.ignored_attrs
      ignore.concat(global) if global&.any?
      return changes unless ignore.any?

      changes.except(*ignore)
    end

    def build_object_from_previous
      delta = {}
      record.previous_changes.each { |attr, (old, _)| delta[attr] = old }
      delta
    end

    def whodunnit
      Context.whodunnit
    end

    def metadata
      Context.metadata
    end
  end
end
