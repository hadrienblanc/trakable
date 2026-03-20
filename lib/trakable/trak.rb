# frozen_string_literal: true

module Trakable
  # Trak model for storing audit records.
  # Each trak represents a single state change event on a tracked item.
  #
  # Inherits from ActiveRecord::Base when available (Rails apps),
  # otherwise works as a plain Ruby object (testing, non-AR contexts).
  #
  class Trak < (defined?(ActiveRecord::Base) ? ActiveRecord::Base : Object)
    include Revertable

    EVENTS = %w[create update destroy].freeze

    if defined?(ActiveRecord::Base) && self < ActiveRecord::Base
      require 'json'

      self.table_name = 'traks'

      serialize :object, coder: JSON
      serialize :changeset, coder: JSON
      serialize :metadata, coder: JSON

      belongs_to :item, polymorphic: true, optional: true
      belongs_to :whodunnit, polymorphic: true, optional: true

      scope :for_item_type, ->(type) { where(item_type: type.to_s) }
      scope :for_event, ->(event) { where(event: event.to_s) }
      scope :for_whodunnit, ->(user) { where(whodunnit_type: user.class.name, whodunnit_id: user.id) }
      scope :created_before, ->(time) { where(arel_table[:created_at].lt(time)) }
      scope :created_after, ->(time) { where(arel_table[:created_at].gt(time)) }
      scope :recent, -> { order(created_at: :desc) }
    else
      ATTRS = %i[id item_type item_id event object changeset
                 whodunnit_type whodunnit_id metadata created_at].freeze

      # Pre-computed ivar symbols to avoid string interpolation in initialize
      ATTR_IVARS = ATTRS.to_h { |a| [a, :"@#{a}"] }.freeze

      attr_accessor(*ATTRS)

      def initialize(attrs = {})
        attrs.each do |key, value|
          ivar = ATTR_IVARS[key]
          instance_variable_set(ivar, value) if ivar
        end
      end

      def self.table_name
        'traks'
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
    end

    class << self
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
