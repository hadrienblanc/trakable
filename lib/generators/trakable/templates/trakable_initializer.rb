# frozen_string_literal: true

# Trakable configuration
# See https://github.com/hadrienblanc/trakable for more options

Trakable.configure do |config|
  # Enable/disable tracking globally
  # config.enabled = true

  # Attributes to ignore by default
  # config.ignored_attrs = %w[created_at updated_at id]

  # Controller method that returns the current user (default: :current_user)
  # config.whodunnit_method = :current_user
end
