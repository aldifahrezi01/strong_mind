# GitHub Push Events Ingestor

Internal service that ingests GitHub public `PushEvent` activity, persists raw and structured data in PostgreSQL, and enriches events with actor/repository metadata.

Built with **Ruby on Rails 7.2 (API-only)**, **PostgreSQL**, and **Docker Compose**.

## Prerequisites

- Docker Desktop (macOS, Windows, or Linux)
- No local Ruby installation required

## Quick start

### 1. Start the system

```bash
docker compose up --build
```

This starts:

- **db** — PostgreSQL 16
- **app** — Rails API on port 3000

Wait until logs show Puma listening and the entrypoint has finished migrations.

### 2. Run ingestion

In a second terminal:

```bash
docker compose run --rm ingest
```

This executes a single ingest cycle: fetch public events, persist new push events, enrich pending rows, and exit.

For continuous ingestion:

```bash
docker compose run --rm app bundle exec rake ingest:continuous
```

### 3. Run tests

```bash
docker compose run --rm test
```

## How to verify it's working

### Expected timing

- **Database ready:** ~10–30 seconds after `docker compose up`
- **First ingest results:** immediately after `docker compose run --rm ingest` completes (typically under 30 seconds with network access)

### Expected logs

After ingestion, look for lines similar to:

```
[entrypoint] Running database migrations...
[ingestion] Starting run id=1
[github] Fetching public events from https://api.github.com/events
[github] Request succeeded rate_limit_remaining=59
[ingestion] Persisted push github_event_id=...
[enrichment] Succeeded github_event_id=... actor=... repo=...
[ingestion] Completed run id=1 fetched=30 seen=... persisted=... skipped=...
```

On duplicate runs, expect `skipped=` to increase and `persisted=0` when no new pushes appear in the feed.

View live logs:

```bash
docker compose logs -f app
```

### HTTP checks

```bash
curl http://localhost:3000/health
curl http://localhost:3000/push_events
curl http://localhost:3000/push_events/<github_event_id>
```

`/health` returns database connectivity, push event count, and the latest ingestion run summary.

### Database checks

Connect to Postgres:

```bash
docker compose exec db psql -U github_events -d github_events_development
```

Useful queries:

```sql
-- Recent ingestion runs
SELECT id, status, events_fetched, push_events_seen, push_events_persisted,
       push_events_skipped, enrichments_succeeded, started_at, finished_at
FROM ingestion_runs
ORDER BY id DESC
LIMIT 5;

-- Persisted push events (structured fields)
SELECT github_event_id, repository_github_id, push_id, ref, head, before,
       enrichment_status, github_created_at
FROM push_events
ORDER BY id DESC
LIMIT 10;

-- Enrichment cache
SELECT login, github_id, fetched_at FROM github_actors ORDER BY id DESC LIMIT 5;
SELECT full_name, github_id, fetched_at FROM github_repositories ORDER BY id DESC LIMIT 5;
```

You should see:

| Table | What to expect |
|-------|----------------|
| `ingestion_runs` | At least one row with `status = completed` after ingest |
| `push_events` | Rows with `enrichment_status = enriched` (or `pending` if rate-limited mid-run) |
| `github_actors` / `github_repositories` | Cached enrichment rows linked from `push_events` |

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_EVENTS_URL` | `https://api.github.com/events` | Events API endpoint (override with fixtures for local experiments) |
| `INGEST_POLL_INTERVAL_SECONDS` | `90` | Delay between continuous ingest cycles |
| `LOG_LEVEL` | `info` | Rails log verbosity |
| `DATABASE_HOST` | `db` | Postgres hostname |

## Project layout

```
app/models/          ActiveRecord models
app/controllers/     Health and push event inspection API
lib/github/          Ingestion, enrichment, GitHub HTTP client
lib/tasks/ingest.rake  Ingestion entrypoints
db/migrate/          Schema migrations
spec/                RSpec tests (WebMock fixtures)
DESIGN.md            Architecture and tradeoffs (1–2 pages)
```

## Design documentation

See [DESIGN.md](DESIGN.md) for problem framing, architecture, rate-limit strategy, idempotency, and intentional scope limits.
