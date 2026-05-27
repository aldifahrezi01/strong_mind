require "faraday"
require "faraday/retry"
require "json"

module Github
  class Client
    DEFAULT_EVENTS_URL = "https://api.github.com/events".freeze
    USER_AGENT = "StrongMind-GithubEventsIngestor/1.0".freeze

    class RateLimitExceeded < StandardError
      attr_reader :reset_at

      def initialize(reset_at)
        @reset_at = reset_at
        super("GitHub API rate limit exceeded; resets at #{reset_at}")
      end
    end

    def initialize(events_url: nil, rate_limit_tracker: RateLimitTracker.new, logger: Rails.logger)
      @events_url = events_url || ENV.fetch("GITHUB_EVENTS_URL", DEFAULT_EVENTS_URL)
      @rate_limit_tracker = rate_limit_tracker
      @logger = logger
      @connection = build_connection
    end

    attr_reader :rate_limit_tracker

    def fetch_events
      @logger.info("[github] Fetching public events from #{@events_url}")
      response = @connection.get(@events_url)
      handle_response!(response)
      JSON.parse(response.body)
    end

    def fetch_resource(url)
      return nil if url.blank?

      @logger.info("[github] Fetching resource #{url}")
      response = @connection.get(url)
      handle_response!(response)
      JSON.parse(response.body)
    end

    private

    def build_connection
      Faraday.new do |f|
        f.headers["Accept"] = "application/vnd.github+json"
        f.headers["User-Agent"] = USER_AGENT
        f.request :retry, max: 3, interval: 1, interval_randomness: 0.5, backoff_factor: 2,
                          retry_statuses: [500, 502, 503, 504],
                          methods: %i[get],
                          exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
        f.adapter Faraday.default_adapter
        f.options.timeout = 15
        f.options.open_timeout = 5
      end
    end

    def handle_response!(response)
      @rate_limit_tracker.update_from_headers(response.headers)

      case response.status
      when 200
        @logger.info(
          "[github] Request succeeded rate_limit_remaining=#{@rate_limit_tracker.remaining}"
        )
      when 403, 429
        if rate_limited_response?(response)
          raise RateLimitExceeded.new(@rate_limit_tracker.reset_at)
        end

        raise Faraday::Error, "GitHub API error #{response.status}: #{response.body}"
      else
        raise Faraday::Error, "GitHub API error #{response.status}: #{response.body}"
      end
    end

    def rate_limited_response?(response)
      remaining = response.headers["x-ratelimit-remaining"]&.to_i
      remaining&.zero? || response.body.to_s.include?("rate limit")
    end
  end
end
