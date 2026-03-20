# frozen_string_literal: true

require 'active_support/concern'

module Trakable
  # Controller concern for automatically setting whodunnit from current_user.
  #
  # Include in your ApplicationController:
  #
  #   class ApplicationController < ActionController::Base
  #     include Trakable::Controller
  #   end
  #
  # By default, uses :current_user method. Configure with:
  #
  #   set_trakable_whodunnit :current_admin
  #
  module Controller
    extend ActiveSupport::Concern

    included do
      # Only register callback if around_action is available (Rails controllers)
      around_action :set_trakable_whodunnit if respond_to?(:around_action)
    end

    class_methods do
      # Configure the method used to get the current user.
      #
      # @param method_name [Symbol] The method name (default: :current_user)
      #
      # @example
      #   set_trakable_whodunnit :current_admin
      #
      def set_trakable_whodunnit(method_name = :current_user)
        @trakable_whodunnit_method = method_name
      end

      def trakable_whodunnit_method
        @trakable_whodunnit_method || :current_user
      end
    end

    private

    def set_trakable_whodunnit(&)
      user = send(self.class.trakable_whodunnit_method)
      Trakable.with_user(user, &)
    end
  end
end
