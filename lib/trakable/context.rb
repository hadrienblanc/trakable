# frozen_string_literal: true

module Trakable
  # Thread-safe context for storing whodunnit and tracking state
  class Context
    THREAD_KEY = :trakable_context

    class << self
      def whodunnit
        context[:whodunnit]
      end

      def whodunnit=(value)
        context[:whodunnit] = value
      end

      def metadata
        context[:metadata]
      end

      def metadata=(value)
        context[:metadata] = value
      end

      def tracking_enabled?
        return Trakable.enabled? unless context.key?(:tracking_enabled)

        context[:tracking_enabled]
      end

      def tracking_enabled=(value)
        context[:tracking_enabled] = value
      end

      def with_user(user)
        raise ArgumentError, 'with_user requires a block' unless block_given?

        previous = whodunnit
        self.whodunnit = user
        yield
      ensure
        self.whodunnit = previous
      end

      def with_tracking
        raise ArgumentError, 'with_tracking requires a block' unless block_given?

        previous = context[:tracking_enabled]
        self.tracking_enabled = true
        yield
      ensure
        if previous.nil?
          context.delete(:tracking_enabled)
        else
          self.tracking_enabled = previous
        end
      end

      def without_tracking
        raise ArgumentError, 'without_tracking requires a block' unless block_given?

        previous = context[:tracking_enabled]
        self.tracking_enabled = false
        yield
      ensure
        if previous.nil?
          context.delete(:tracking_enabled)
        else
          self.tracking_enabled = previous
        end
      end

      def reset!
        Thread.current.thread_variable_set(THREAD_KEY, nil)
      end

      private

      def context
        Thread.current.thread_variable_get(THREAD_KEY) ||
          Thread.current.thread_variable_set(THREAD_KEY, {})
      end
    end
  end
end
