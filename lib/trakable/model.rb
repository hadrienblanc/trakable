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
      #   callback_type: :after (default) or :after_commit
      #
      def trakable(options = {})
        normalized = options.dup
        callback_type = normalized.delete(:callback_type) || :after

        # Pre-convert symbols to strings for performance
        normalized[:only] = Array(normalized[:only]).map(&:to_s) if normalized[:only]
        normalized[:ignore] = Array(normalized[:ignore]).map(&:to_s) if normalized[:ignore]

        self.trakable_options = normalized

        register_trakable_callbacks(normalized[:on], callback_type)
      end

      private

      def register_trakable_callbacks(events, callback_type = :after)
        events = Array(events).presence || %i[create update destroy]

        if callback_type == :after_commit
          register_after_commit_callbacks(events)
        else
          register_after_callbacks(events)
        end
      end

      def register_after_callbacks(events)
        events.each do |event|
          case event.to_sym
          when :create  then after_create :trak_create
          when :update  then after_update :trak_update
          when :destroy then after_destroy :trak_destroy
          end
        end
      end

      def register_after_commit_callbacks(events)
        events.each do |event|
          case event.to_sym
          when :create  then after_commit(on: :create, &:trak_create)
          when :update  then after_commit(on: :update, &:trak_update)
          when :destroy then after_commit(on: :destroy, &:trak_destroy)
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
