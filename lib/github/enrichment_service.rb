module Github
  class EnrichmentService
    def initialize(client: Client.new, logger: Rails.logger)
      @client = client
      @logger = logger
    end

    def enrich!(push_event)
      event = push_event.raw_payload
      actor_data = event["actor"] || {}
      repo_data = event["repo"] || {}

      actor = find_or_fetch_actor(actor_data)
      repository = find_or_fetch_repository(repo_data)

      push_event.update!(
        github_actor: actor,
        github_repository: repository,
        enrichment_status: "enriched",
        last_error: nil
      )

      @logger.info(
        "[enrichment] Succeeded github_event_id=#{push_event.github_event_id} " \
        "actor=#{actor&.login} repo=#{repository&.full_name}"
      )
      true
    rescue StandardError => e
      push_event.update!(
        enrichment_status: "failed",
        last_error: e.message,
        retry_count: push_event.retry_count + 1
      )
      @logger.error(
        "[enrichment] Failed github_event_id=#{push_event.github_event_id} error=#{e.class}: #{e.message}"
      )
      false
    end

    def enrich_pending!(limit: 50)
      succeeded = 0
      failed = 0

      PushEvent.pending_enrichment.limit(limit).find_each do |push_event|
        if @client.rate_limit_tracker.exhausted?
          @logger.warn("[enrichment] Pausing enrichment; rate limit exhausted")
          break
        end

        if enrich!(push_event)
          succeeded += 1
        else
          failed += 1
        end
      end

      { succeeded: succeeded, failed: failed }
    end

    private

    def find_or_fetch_actor(actor_data)
      github_id = actor_data["id"]
      api_url = actor_data["url"]
      return nil if github_id.blank? && api_url.blank?

      existing = GithubActor.find_by(github_id: github_id) if github_id.present?
      existing ||= GithubActor.find_by(api_url: api_url) if api_url.present?
      return existing if existing

      payload = fetch_with_cache_fallback(api_url, actor_data)
      return nil unless payload

      GithubActor.create!(
        github_id: payload["id"] || github_id,
        login: payload["login"] || actor_data["login"],
        api_url: payload["url"] || api_url,
        raw_payload: payload,
        fetched_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      GithubActor.find_by!(github_id: payload["id"] || github_id)
    end

    def find_or_fetch_repository(repo_data)
      github_id = repo_data["id"]
      api_url = repo_url_from_event_repo(repo_data)
      full_name = repo_data["name"]

      existing = GithubRepository.find_by(github_id: github_id) if github_id.present?
      existing ||= GithubRepository.find_by(api_url: api_url) if api_url.present?
      return existing if existing

      payload = fetch_with_cache_fallback(api_url, repo_data)
      return nil unless payload

      GithubRepository.create!(
        github_id: payload["id"] || github_id,
        full_name: payload["full_name"] || full_name,
        api_url: payload["url"] || api_url,
        raw_payload: payload,
        fetched_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      GithubRepository.find_by!(github_id: payload["id"] || github_id)
    end

    def repo_url_from_event_repo(repo_data)
      return repo_data["url"] if repo_data["url"].present?

      name = repo_data["name"]
      return nil if name.blank?

      "https://api.github.com/repos/#{name}"
    end

    def fetch_with_cache_fallback(api_url, fallback_payload)
      return fallback_payload if api_url.blank? || @client.rate_limit_tracker.low?

      @client.fetch_resource(api_url)
    rescue Client::RateLimitExceeded
      @logger.warn("[enrichment] Using event-embedded payload due to rate limit url=#{api_url}")
      fallback_payload
    end
  end
end
