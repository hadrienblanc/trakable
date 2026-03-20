# frozen_string_literal: true

module Trakable
  # Revertable provides methods for restoring previous states from Traks.
  #
  # Included in Trak to provide:
  # - reify: Build a non-persisted record with state at this Trak
  # - revert!: Restore the record to the state before this Trak
  #
  # Included in Model to provide:
  # - trak_at: Get state at a specific timestamp
  #
  module Revertable
    # Build a non-persisted record with the state stored in this Trak.
    #
    # For update/destroy traks, uses the object (state before change).
    # For create traks, returns nil (no previous state exists).
    #
    # @return [ActiveRecord::Base, nil] Non-persisted record or nil for create events
    #
    # @example
    #   trak = post.traks.last
    #   previous_state = trak.reify
    #   previous_state.title # => "Old Title"
    #   previous_state.persisted? # => false
    #
    def reify
      return nil if create?
      return nil if object.nil? || object.empty?

      model_class.new.tap do |record|
        # Start with current attributes if the item still exists
        if (current = item)
          current.attributes.each do |attr, val|
            record.write_attribute(attr, val) if record.respond_to?(attr)
          end
        end
        # Apply stored old values on top (delta or full snapshot)
        object.each do |attr, value|
          record.write_attribute(attr, value) if record.respond_to?(attr)
        end
      end
    end

    # Restore the record to the state before this Trak was created.
    #
    # For create traks: destroys the record
    # For update traks: restores attributes before the change
    # For destroy traks: re-creates the record with old attributes (new primary key)
    #
    # @param trak_revert [Boolean] Whether to create a new trak for this revert
    # @return [ActiveRecord::Base, true, false] The restored record or true/false for success
    #
    # @example
    #   post.traks.last.revert! # => restores previous state
    #   post.traks.last.revert!(trak_revert: true) # => restores and creates a trak
    #
    def revert!(trak_revert: false)
      case event
      when 'create'
        perform_revert_create(trak_revert: trak_revert)
      when 'update'
        perform_revert_update(trak_revert: trak_revert)
      when 'destroy'
        perform_revert_destroy(trak_revert: trak_revert)
      end
    end

    private

    def model_class
      item_type.constantize
    rescue NameError
      raise "Cannot reify: model class #{item_type} not found"
    end

    def perform_revert_create(trak_revert:) # rubocop:disable Naming/PredicateMethod
      target = item
      return false unless target

      Trakable.without_tracking { target.destroy }

      build_revert_trak if trak_revert
      true
    end

    def perform_revert_update(trak_revert:)
      target = item
      return false unless target

      restored = reify
      return false unless restored

      Trakable.without_tracking do
        object&.each do |attr, value|
          target.write_attribute(attr, value) if target.respond_to?(attr)
        end
        target.save!(validate: false)
      end

      build_revert_trak if trak_revert
      target
    end

    def perform_revert_destroy(trak_revert:)
      restored = reify
      return false unless restored

      Trakable.without_tracking { restored.save!(validate: false) }

      build_revert_trak(restored) if trak_revert
      restored
    end

    def build_revert_trak(restored_item = nil)
      Trakable::Tracker.call(restored_item || item, 'revert')
    end
  end

  # Module for Model concern to add trak_at method
  module ModelRevertable
    # Get the state of this record at a specific point in time.
    #
    # @param timestamp [Time, DateTime] The point in time
    # @return [ActiveRecord::Base, nil] Non-persisted record with state at that time, or nil
    #
    # @example
    #   post.trak_at(1.day.ago) # => post state from 1 day ago
    #   post.trak_at(Time.now + 1.hour) # => current state (future returns current)
    #
    def trak_at(timestamp)
      timestamp = timestamp.to_time if timestamp.respond_to?(:to_time)

      return nil if before_creation?(timestamp)

      target_trak = find_trak_at(timestamp)

      reify_or_dup(target_trak)
    end

    private

    def before_creation?(timestamp)
      respond_to?(:created_at) && created_at && timestamp < created_at
    end

    def find_trak_at(timestamp)
      if traks.respond_to?(:where)
        traks.where('created_at <= ?', timestamp).order(created_at: :desc).first
      else
        traks.select { |t| t.created_at <= timestamp }.max_by(&:created_at)
      end
    end

    def reify_or_dup(target_trak)
      return dup.tap { |r| r.id = nil } if target_trak.nil?

      target_trak.reify || dup.tap { |r| r.id = nil }
    end
  end
end
