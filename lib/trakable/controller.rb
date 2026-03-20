# frozen_string_literal: true

require 'active_support/concern'

module Trakable
  # Controller concern for automatically setting whodunnit.
  #
  # Auto-included in ActionController::Base via Railtie.
  # Uses Trakable.configuration.whodunnit_method (default: :current_user).
  #
  module Controller
    extend ActiveSupport::Concern

    included do
      around_action :_set_trakable_whodunnit if respond_to?(:around_action)
    end

    private

    def _set_trakable_whodunnit(&)
      user = send(Trakable.configuration.whodunnit_method)
      Trakable.with_user(user, &)
    end
  end
end
