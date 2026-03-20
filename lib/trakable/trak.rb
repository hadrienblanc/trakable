# frozen_string_literal: true

require 'json'

module Trakable
  # Trak model for storing audit records.
  # Each trak represents a single state change event on a tracked item.
  # This is a plain Ruby class - the actual persistence is handled by
  # the host application's ActiveRecord model.
  class Trak
    EVENTS = %w[create update destroy].freeze

    attr_accessor :id,
                  :item_type,
                  :item_id,
                  :event,
                  :object_raw,
                  :changeset_raw,
                  :whodunnit_type,
                  :whodunnit_id,
                  :metadata_raw,
                  :created_at

    class << self
      def table_name
        'traks'
      end

      def for_model(model_class)
        where(item_type: model_class.to_s)
      end

      def by_event(event)
        where(event: event.to_s)
      end

      def between(start_time, end_time)
        where(created_at: start_time..end_time)
      end

      def by_whodunnit(actor)
        where(whodunnit_type: actor.class.to_s, whodunnit_id: actor.id)
      end

      def for_item(item)
        where(item_type: item.class.to_s, item_id: item.id)
      end

      def chronological
        order(:created_at, :id)
      end

      def reverse_chronological
        order(created_at: :desc, id: :desc)
      end

      def recent(limit = 10)
        reverse_chronological.limit(limit)
      end

      def build(item:, event:, changeset:, object: nil, whodunnit: nil, metadata: nil)
        new(
          item_type: item.class.to_s,
          item_id: item.id,
          event: event,
          object: object,
          changeset: changeset,
          whodunnit_type: whodunnit&.class&.to_s,
          whodunnit_id: whodunnit&.id,
          metadata: metadata,
          created_at: Time.now
        )
      end
    end

    def initialize(attrs = {})
      attrs.each do |key, value|
        setter = "#{key}="
        send(setter, value) if respond_to?(setter)
      end
    end

    def item
      return nil unless item_type && item_id

      @item ||= item_type.constantize.find_by(id: item_id)
    rescue NameError
      nil
    end

    def whodunnit
      return nil unless whodunnit_type && whodunnit_id

      @whodunnit ||= whodunnit_type.constantize.find_by(id: whodunnit_id)
    rescue NameError
      nil
    end

    def object
      deserialize(@object_raw)
    end

    def object=(value)
      @object_raw = serialize(value)
    end

    def changeset
      deserialize(@changeset_raw)
    end

    def changeset=(value)
      @changeset_raw = serialize(value)
    end

    def metadata
      deserialize(@metadata_raw)
    end

    def metadata=(value)
      @metadata_raw = serialize(value)
    end

    def create?
      event == 'create'
    end

    def update?
      event == 'update'
    end

    def destroy?
      event == 'destroy'
    end

    private

    def deserialize(value)
      return nil if value.nil? || (value.respond_to?(:empty?) && value.empty?)

      JSON.parse(value.to_s)
    rescue JSON::ParserError
      nil
    end

    def serialize(value)
      return nil if value.nil?

      value.to_json
    end
  end
end
