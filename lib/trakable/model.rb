# frozen_string_literal: true

require 'active_support/concern'

module Trakable
  # Trakable Model Concern
  #
  # Include this in your ActiveRecord models to enable tracking:
  #
  #   class Post < ApplicationRecord
  #     include Trakable::Model
  #     trakable only: %i[title body], ignore: %i[views_count]
  #   end
  #
  module Model
    extend ActiveSupport::Concern

    included do
      # Store trakable options at class level
      class_attribute :trakable_options, instance_writer: false, default: {}

      # has_many :traks association
      has_many :traks, as: :item, class_name: 'Trakable::Trak', dependent: :nullify

      # Include revertable methods
      include ModelRevertable
    end

    class_methods do
      # Configure tracking for this model
      #
      # Options:
      #   only:    Array of attrs to track (default: all except ignored)
      #   ignore:  Array of attrs to skip (default: global ignored_attrs)
      #   if:      Proc/Method name - track only if true
      #   unless:  Proc/Method name - skip tracking if true
      #   on:      Array of events to track (default: %i[create update destroy])
      #
      def trakable(options = {})
        self.trakable_options = options.dup

        # Register callbacks for tracking
        register_trakable_callbacks(options[:on])
      end

      private

      def register_trakable_callbacks(events)
        events = Array(events).presence || %i[create update destroy]

        events.each do |event|
          case event.to_sym
          when :create
            after_create :trak_create
          when :update
            after_update :trak_update
          when :destroy
            after_destroy :trak_destroy
          end
        end
      end
    end

    def trak_create
      Trakable::Tracker.call(self, 'create')
    end

    def trak_update
      Trakable::Tracker.call(self, 'update')
    end

    def trak_destroy
      Trakable::Tracker.call(self, 'destroy')
    end
  end
end
