require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module GithubEventsIngestor
  class Application < Rails::Application
    config.load_defaults 7.2
    config.autoload_lib(ignore: %w[assets tasks])
    config.api_only = true
    config.active_job.queue_adapter = :async
    config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym
    config.time_zone = "UTC"
  end
end
