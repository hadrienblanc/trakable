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
      #   only:          Array of attrs to track (default: all except ignored)
      #   ignore:        Array of attrs to skip (default: global ignored_attrs)
      #   if:            Proc/Method name - track only if true
      #   unless:        Proc/Method name - skip tracking if true
      #   on:            Array of events to track (default: %i[create update destroy])
      #   callback_type: :after or :after_commit (default: :after)
      #                  Use :after_commit to track after transaction commits
      #
      def trakable(options = {})
        normalized = options.dup
        callback_type = normalized.delete(:callback_type) || :after

        self.trakable_options = normalized

        # Register callbacks for tracking
        register_trakable_callbacks(normalized[:on], callback_type)
      end

      private

      def register_trakable_callbacks(events, callback_type = :after)
        events = Array(events).presence || %i[create update destroy]

        events.each do |event|
          method_name = "trak_#{event}"

          if callback_type == :after_commit
            after_commit on: event, &:trak_create if event == :create
            after_commit on: event, &:trak_update if event == :update
            after_commit on: event, &:trak_destroy if event == :destroy
          else
            case event.to_sym
            when :create
              after_create method_name
            when :update
              after_update method_name
            when :destroy
              after_destroy method_name
            end
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
