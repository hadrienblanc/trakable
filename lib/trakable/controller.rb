# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

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
      class_attribute :trakable_whodunnit_method, instance_writer: false, default: :current_user

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
        self.trakable_whodunnit_method = method_name
      end
    end

    private

    def set_trakable_whodunnit(&)
      user = send(trakable_whodunnit_method)
      Trakable.with_user(user, &)
    end
  end
end
