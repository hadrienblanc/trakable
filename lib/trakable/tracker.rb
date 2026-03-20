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

      trak = build_trak
      Cleanup.run(record) if trak
      trak
    end

    private

    def tracking_enabled?
      return false unless Trakable.enabled?
      Context.tracking_enabled?
    end

    def skip?
      return false unless record.respond_to?(:trakable_options)

      skip_if_condition? || skip_unless_condition?
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
      Trak.build(
        item: record,
        event: event,
        changeset: changeset,
        object: object_state,
        whodunnit: whodunnit,
        metadata: metadata
      )
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

      only = only_attrs
      ignore = ignore_attrs

      if only
        only_set = only.to_set
        ignore_set = ignore.to_set
        changes.select { |k, _| only_set.include?(k) && !ignore_set.include?(k) }
      elsif ignore.any?
        ignore_set = ignore.to_set
        changes.reject { |k, _| ignore_set.include?(k) }
      else
        changes
      end
    end

    def only_attrs
      return nil unless record.respond_to?(:trakable_options)
      only = record.trakable_options[:only]
      return nil unless only
      # Convert to strings if needed (defensive - should be pre-converted by Model#trakable)
      only.first.is_a?(String) ? only : only.map(&:to_s)
    end

    def ignore_attrs
      ignore = []
      if record.respond_to?(:trakable_options) && record.trakable_options[:ignore]
        ignored = record.trakable_options[:ignore]
        # Convert to strings if needed
        ignored_strings = ignored.first.is_a?(String) ? ignored : ignored.map(&:to_s)
        ignore.concat(ignored_strings)
      end
      if Trakable.configuration.ignored_attrs
        # Configuration.ignored_attrs is pre-converted to strings
        ignore.concat(Trakable.configuration.ignored_attrs)
      end
      ignore
    end

    def build_object_from_previous
      current = record.attributes.except('id')

      record.previous_changes.each do |attr, (old, _new)|
        current[attr] = old
      end

      current
    end

    def whodunnit
      Context.whodunnit
    end

    def metadata
      Context.metadata
    end
  end
end
