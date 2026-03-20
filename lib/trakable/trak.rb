# frozen_string_literal: true

module Trakable
  # Trak model for storing audit records.
  # Each trak represents a single state change event on a tracked item.
  #
  # This is a plain Ruby class that can be used as a template for the host app's
  # ActiveRecord model. The host app should create:
  #
  #   class Trak < ApplicationRecord
  #     self.table_name = 'traks'
  #     serialize :object, coder: JSON
  #     serialize :changeset, coder: JSON
  #     serialize :metadata, coder: JSON
  #   end
  #
  class Trak
    include Revertable

    EVENTS = %w[create update destroy].freeze

    ATTRS = %i[id item_type item_id event object changeset
               whodunnit_type whodunnit_id metadata created_at].freeze

    # Pre-computed ivar symbols to avoid string interpolation in initialize
    ATTR_IVARS = ATTRS.each_with_object({}) { |a, h| h[a] = :"@#{a}" }.freeze

    attr_accessor(*ATTRS)

    class << self
      def table_name
        'traks'
      end

      def build(item:, event:, changeset:, object: nil, whodunnit: nil, metadata: nil)
        new(
          item_type: item.class.name,
          item_id: item.id,
          event: event,
          object: object,
          changeset: changeset,
          whodunnit_type: whodunnit&.class&.name,
          whodunnit_id: whodunnit&.id,
          metadata: metadata,
          created_at: Time.now
        )
      end
    end

    def initialize(attrs = {})
      attrs.each do |key, value|
        ivar = ATTR_IVARS[key]
        instance_variable_set(ivar, value) if ivar
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

    def create?
      event == 'create'
    end

    def update?
      event == 'update'
    end

    def destroy?
      event == 'destroy'
    end
  end
end
