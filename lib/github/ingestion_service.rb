module Github
  class IngestionService
    def initialize(
      client: Client.new,
      enrichment_service: nil,
      logger: Rails.logger,
      sleep_fn: ->(seconds) { sleep(seconds) }
    )
      @client = client
      @enrichment_service = enrichment_service || EnrichmentService.new(client: client, logger: logger)
      @logger = logger
      @sleep_fn = sleep_fn
    end

    def run_once!
      run = IngestionRun.create!(status: "running", started_at: Time.current)
      @logger.info("[ingestion] Starting run id=#{run.id}")

      events = @client.fetch_events
      run.events_fetched = events.size

      events.each do |event|
        next unless event.is_a?(Hash)
        next unless event["type"] == "PushEvent"

        run.push_events_seen += 1
        persist_push_event(event, run)
      end

      enrichment_stats = @enrichment_service.enrich_pending!
      run.enrichments_succeeded = enrichment_stats[:succeeded]
      run.enrichments_failed = enrichment_stats[:failed]
      run.complete!(status: "completed")

      @logger.info(
        "[ingestion] Completed run id=#{run.id} fetched=#{run.events_fetched} " \
        "seen=#{run.push_events_seen} persisted=#{run.push_events_persisted} " \
        "skipped=#{run.push_events_skipped} enriched=#{run.enrichments_succeeded}"
      )
      run
    rescue Client::RateLimitExceeded => e
      run&.complete!(status: "rate_limited", error_message: e.message)
      @logger.warn("[ingestion] Rate limited; will retry after reset error=#{e.message}")
      sleep_until_rate_limit_reset
      raise
    rescue StandardError => e
      run&.complete!(status: "failed", error_message: e.message)
      @logger.error("[ingestion] Failed error=#{e.class}: #{e.message}")
      raise
    end

    def run_continuous!(interval_seconds: nil)
      loop do
        run_once!
        sleep_seconds = interval_seconds || next_poll_interval
        @logger.info("[ingestion] Sleeping #{sleep_seconds}s before next poll")
        @sleep_fn.call(sleep_seconds)
      rescue Client::RateLimitExceeded
        sleep_seconds = [@client.rate_limit_tracker.seconds_until_reset, 60].max
        @logger.warn("[ingestion] Rate limited; sleeping #{sleep_seconds}s")
        @sleep_fn.call(sleep_seconds)
      rescue StandardError => e
        @logger.error("[ingestion] Transient failure; backing off error=#{e.class}: #{e.message}")
        @sleep_fn.call(30)
      end
    end

    private

    def persist_push_event(event, run)
      before_count = PushEvent.count
      record = PushEvent.upsert_from_github_event!(event)
      if PushEvent.count > before_count
        run.push_events_persisted += 1
        @logger.info("[ingestion] Persisted push github_event_id=#{record.github_event_id}")
      else
        run.push_events_skipped += 1
        @logger.debug("[ingestion] Skipped duplicate github_event_id=#{record.github_event_id}")
      end
      run.save!
    rescue StandardError => e
      @logger.error(
        "[ingestion] Failed to persist malformed event id=#{event['id']} error=#{e.class}: #{e.message}"
      )
    end

    def next_poll_interval
      tracker = @client.rate_limit_tracker
      return tracker.seconds_until_reset if tracker.exhausted?
      return 120 if tracker.low?

      ENV.fetch("INGEST_POLL_INTERVAL_SECONDS", "90").to_i
    end

    def sleep_until_rate_limit_reset
      seconds = @client.rate_limit_tracker.seconds_until_reset
      @sleep_fn.call(seconds) if seconds.positive?
    end
  end
end
