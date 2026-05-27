module Github
  class RateLimitTracker
    attr_reader :limit, :remaining, :reset_at

    def initialize
      @limit = nil
      @remaining = nil
      @reset_at = nil
      @mutex = Mutex.new
    end

    def update_from_headers(headers)
      @mutex.synchronize do
        @limit = headers["x-ratelimit-limit"]&.to_i if headers["x-ratelimit-limit"]
        @remaining = headers["x-ratelimit-remaining"]&.to_i if headers["x-ratelimit-remaining"]
        reset_epoch = headers["x-ratelimit-reset"]&.to_i
        @reset_at = Time.at(reset_epoch).utc if reset_epoch&.positive?
      end
    end

    def exhausted?
      remaining.present? && remaining <= 0
    end

    def low?
      remaining.present? && remaining <= 2
    end

    def seconds_until_reset
      return 0 unless reset_at

      [reset_at - Time.current, 0].max.ceil
    end

    def recommended_sleep_seconds
      return seconds_until_reset if exhausted?

      low? ? 30 : 0
    end
  end
end
