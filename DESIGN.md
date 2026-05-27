# Design Brief — GitHub Push Events Ingestor

## Problem understanding

StrongMind needs durable, queryable visibility into GitHub **Push** activity. The public Events API (`https://api.github.com/events`) exposes a high-volume, mixed feed of recent activity across all of GitHub. The service must:

1. Poll that feed without authenticated credentials (60 requests/hour/IP).
2. Filter to `PushEvent` records only.
3. Persist raw payloads for audit plus structured columns for analyst queries.
4. Enrich pushes with actor and repository details using URLs embedded in each event.
5. Run unattended with clear logs, graceful degradation, and restart safety.

The exercise prioritizes predictable operability over feature breadth. I treated this as an internal ingestion pipeline with a thin read API for inspection, not a full analytics platform.

## Architecture

```
┌─────────────────┐     poll (adaptive)      ┌──────────────────┐
│ GitHub Events   │ ───────────────────────► │ IngestionService │
│ API             │                          └────────┬─────────┘
└─────────────────┘                                   │
                                                        │ filter PushEvent
                                                        ▼
                                               ┌──────────────────┐
                                               │ push_events      │
                                               │ (raw + columns)  │
                                               └────────┬─────────┘
                                                        │
                        enrich (cached GETs)            ▼
┌─────────────────┐                          ┌──────────────────┐
│ GitHub User/    │ ◄────────────────────────│ EnrichmentService│
│ Repo APIs       │                          └────────┬─────────┘
└─────────────────┘                                   │
                                                        ▼
                                               ┌──────────────────┐
                                               │ github_actors    │
                                               │ github_repositories│
                                               └──────────────────┘
```

**Stack:** Ruby on Rails 7.2 (API-only), PostgreSQL, Faraday, Docker Compose.

**Components:**

| Component | Responsibility |
|-----------|----------------|
| `Github::Client` | HTTP to GitHub, retries on 5xx, rate-limit header tracking |
| `Github::IngestionService` | One-shot or continuous ingest loops, run metrics |
| `Github::EnrichmentService` | Actor/repo lookup with DB-backed cache |
| `PushEvent` | Idempotent persistence, structured fields + `raw_payload` JSONB |
| `IngestionRun` | Per-cycle operability counters |
| Health / Push Events API | Operator verification (`/health`, `/push_events`) |

## Data model (high level)

- **`push_events`** — One row per GitHub event id (unique). Stores full `raw_payload`, queryable `repository_github_id`, `push_id`, `ref`, `head`, `before`, enrichment status, and foreign keys to enriched entities.
- **`github_actors`** / **`github_repositories`** — Deduplicated enrichment cache keyed by GitHub id and API URL; `raw_payload` retained for audit.
- **`ingestion_runs`** — Operational record per ingest cycle (counts, status, errors).

Structured columns mirror GitHub's push payload shape so analysts can filter without JSON operators, while `raw_payload` preserves the authoritative source document.

## Rate limits and durability

**Rate limiting (Extension A):**

- Unauthenticated GitHub REST allows ~60 requests/hour. Every response updates `Github::RateLimitTracker` from `X-RateLimit-*` headers.
- When remaining ≤ 0, `Github::Client` raises `RateLimitExceeded`; ingestion marks the run `rate_limited` and sleeps until `X-RateLimit-Reset`.
- When remaining is low (≤ 2), polling backs off (default 90s normal, 120s when low) to avoid exhausting the budget on enrichment fan-out.
- Enrichment skips redundant GETs when actor/repo rows already exist; when the budget is low, it falls back to actor/repo objects embedded in the event payload rather than amplifying API calls.

**Durability & idempotency (Extension B):**

- `push_events.github_event_id` has a unique index; replays skip duplicates safely.
- Enrichment entities are upsert-guarded with unique indexes on `github_id` and `api_url`.
- Malformed events are logged and skipped without aborting the cycle.
- Transient failures use Faraday retry (5xx/timeouts); continuous mode catches errors, logs, and sleeps 30s instead of crash-looping.

**Durability of writes:** All persistence uses ActiveRecord transactions per record; PostgreSQL is the system of record.

## Observability (Story 4)

Structured log prefixes: `[ingestion]`, `[enrichment]`, `[github]`, `[entrypoint]`. Each successful push log includes `github_event_id`; failures include exception class/message. `IngestionRun` rows summarize each cycle for post-hoc diagnosis.

## Assumptions and tradeoffs

| Decision | Rationale | Tradeoff |
|----------|-----------|----------|
| Poll public `/events` | Required; no token | Only sees recent global activity (~30 events/page), not org-scoped history |
| Single-process ingest rake task | Simple, meets "repeatable or continuous" | Not horizontally scaled; acceptable for exercise scope |
| Enrichment cache in Postgres | Avoids repeat fetches | Cache can become stale; no TTL refresh in core scope |
| API-only Rails | Matches ingestion + verification needs | No admin UI |
| 90s default poll interval | Reduces wasted calls under 60/hr cap | Higher latency for new pushes |

## Intentionally not built

- Authenticated GitHub access or org/repository-scoped feeds
- Message queue / worker pool (Sidekiq, Kafka)
- Object storage for avatars/raw events (Extension C)
- Historical backfill beyond what the public feed exposes
- Metrics backend (Prometheus/Datadog) — stdout logs only
- Full REST API for analytics queries beyond basic push listing

## Testing strategy (Extension D)

RSpec unit/integration tests with WebMock fixtures cover:

- Push event parsing and idempotency
- Rate-limit header handling
- End-to-end ingest + enrichment against deterministic fixtures

Tests avoid live GitHub calls so CI/reviewers get reliable, fast feedback. Live verification is documented in the README.
