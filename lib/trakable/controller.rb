# frozen_string_literal: true

require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

module Trakable
  # Controller concern for automatically setting whodunnit.
  #
  # Auto-included in ActionController::Base via Railtie.
  # Uses Trakable.configuration.whodunnit_method (default: :current_user).
  #
  # Override per-controller:
  #
  #   class AdminController < ApplicationController
  #     set_trakable_whodunnit :current_admin
  #   end
  #
  module Controller
    extend ActiveSupport::Concern

    included do
      class_attribute :trakable_whodunnit_method, instance_writer: false,
                                                  default: Trakable.configuration.whodunnit_method

      around_action :set_trakable_whodunnit if respond_to?(:around_action)
    end

    class_methods do
      # Override the whodunnit method for this controller.
      def set_trakable_whodunnit(method_name)
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
