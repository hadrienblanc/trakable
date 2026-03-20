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
      return true unless Context.respond_to?(:tracking_enabled?)

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

      result = changes.dup
      result = apply_only_filter(result)
      apply_ignore_filters(result)
    end

    def apply_only_filter(result)
      return result unless record.respond_to?(:trakable_options)

      only = record.trakable_options[:only]
      return result unless only

      result.slice(*Array(only).map(&:to_s))
    end

    def apply_ignore_filters(result)
      result = apply_record_ignore_filter(result)
      apply_global_ignore_filter(result)
    end

    def apply_record_ignore_filter(result)
      return result unless record.respond_to?(:trakable_options)

      ignored = record.trakable_options[:ignore]
      return result unless ignored

      result.except(*Array(ignored).map(&:to_s))
    end

    def apply_global_ignore_filter(result)
      global_ignored = Trakable.configuration.ignored_attrs
      return result unless global_ignored

      result.except(*Array(global_ignored).map(&:to_s))
    end

    def build_object_from_previous
      current = record.attributes.except('id')

      record.previous_changes.each do |attr, (old, _new)|
        current[attr] = old
      end

      current
    end

    def whodunnit
      Context.whodunnit if Context.respond_to?(:whodunnit)
    end

    def metadata
      Context.metadata if Context.respond_to?(:metadata)
    end
  end
end
