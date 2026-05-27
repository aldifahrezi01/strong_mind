require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.active_support.deprecation = :notify
  config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym
  config.log_tags = [:request_id]
end
