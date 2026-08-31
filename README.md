# Newsroom Analytics Demo

**A GA4-native web analytics pipeline for a fictional digital newspaper — *The Meridian Post* — running the real GA4 export schema on Neon PostgreSQL with a ported dbt-ga4 transformation layer.**

Most analytics portfolios point at tired CSV samples. This one is different: the raw layer **is the GA4 BigQuery export schema** — the exact `events_*` table structure Google ships ([schema reference](https://support.google.com/analytics/answer/7029846)) — populated with a full year (2025-04-01 → 2026-03-31) of synthetic but realistic newsroom traffic: breaking-news spikes, weekend dips, email/push campaigns with real UTM payloads, consent-denied hits, late-arriving data patterns. On top of it sits the [Velir/dbt-ga4](https://github.com/Velir/dbt-ga4) transformation package, ported to PostgreSQL, running its daily incremental models — including 30-day last-non-direct session attribution.

## Architecture

```
┌────────────────────────┐   ┌─────────────────────────────────────┐
│ GA4 export simulator   │   │ Neon PostgreSQL                      │
│ (private generator)    │──►│                                     │
│ 1 year, 1,000 articles │   │ analytics_3847629104 (GA4 "dataset") │
│ GA4 export schema,     │   │  └─ events (partitioned daily:       │
│ daily sharded events   │   │     events_YYYYMMDD partitions)      │
└────────────────────────┘   │ cms (CMS + CRM export)               │
                             │  ├─ articles                        │
                             │  └─ users                           │
                             └──────────────┬──────────────────────┘
                                            │  dbt (daily incremental)
                                            ▼
                             ┌─────────────────────────────────────┐
                             │ packages/dbt_ga4_pg                  │
                             │ Velir/dbt-ga4 6.2.0 → Postgres port  │
                             │ + project models (newsroom marts)    │
                             └──────────────┬──────────────────────┘
                                            │
                     ga4_stg / ga4_marts schemas
                     dim/fct sessions (daily) · pages ·
                     30-day last-non-direct attribution ·
                     article performance (GA4 × CMS join)
```

## The raw layer: strictly the GA4 export schema

`db/ga4_schema.sql` recreates the GA4 BigQuery export on Postgres:

- **`analytics_3847629104.events`** — the `events` export table. GA4 exports a daily-sharded `events_YYYYMMDD` table per day into a BigQuery dataset named `analytics_<property_id>`; on Postgres we get the same thing natively: one table, **range-partitioned on `event_date` ('YYYYMMDD' text, exactly the BQ STRING type), with partitions named `events_YYYYMMDD`**.
- Nested `RECORD` columns (`event_params`, `user_properties`, `device`, `geo`, `traffic_source`, `collected_traffic_source`, ...) are stored as **JSONB** in the export's key/value shape.
- `traffic_source` is populated only on `session_start` / `first_visit` events — matching real export behaviour.
- `collected_traffic_source` carries UTM/gclid payloads on campaign landings.
- `cms.articles` / `cms.users` — the CMS and CRM exports every newsroom joins against GA4.
- Consent-denied hits (null `user_pseudo_id`), `ga_session_id`/`ga_session_number` on every session event, micros timestamps, batch ordering fields — the fidelity details are documented in `docs/ga4-export-schema.md`.

## The dbt layer: Velir/dbt-ga4, ported to Postgres

`packages/dbt_ga4_pg` is a vendored port of [Velir/dbt-ga4](https://github.com/Velir/dbt-ga4) v6.2.0 (MIT). Same model names, same logic, same semantics — translated for Postgres (UNNEST → JSONB, insert_overwrite partitions → incremental delete+insert windows, IGNORE NULLS windows → equivalent SQL). See the [port's README](packages/dbt_ga4_pg/README.md) for the full translation table.

What runs daily (GitHub Action → Neon):

- **`dim_ga4__sessions_daily` / `fct_ga4__sessions_daily`** — session dimension & metrics, incremental by day
- **`stg_ga4__sessions_traffic_sources_daily` + `last_non_direct`** — session source attribution with the **30-day lookback** (`session_attribution_lookback_window_days: 30`)
- **`fct_ga4__pages`** — page metrics incl. engaged time (the package's page_engagement_key trick)
- **`dim_ga4__client_keys` / `fct_ga4__user_ids`** — user-level identity stitching (GA4 `user_id` ↔ `user_pseudo_id`)
- **`newsletter_signup` = conversion event**, counted per session and per page
- Newsroom marts: **`fct_newsroom__articles_daily`** (GA4 × CMS: page views, scroll depth, video, shares, engagement per article), **`fct_newsroom__articles_daily_by_reader_type`** (the same article metrics split into subscriber / registered / anonymous readers, with subscription tier, via the CRM join), and **`fct_newsroom__traffic_sources_daily`** (sessions by channel grouping)

The incremental models reprocess a **3-day window per run** — the same late-arrival pattern GA4 itself uses ("Analytics will update the daily tables for up to three days after the event date").

## Repo layout

```
db/ga4_schema.sql          raw layer DDL (GA4 export emulation on Postgres)
dbt/                       dbt project (models, vars, CI profile example)
packages/dbt_ga4_pg/       vendored Velir/dbt-ga4 port for Postgres
.github/workflows/          daily dbt build via GitHub Actions
docs/                      GA4 export schema notes
```

## Running it

```bash
# apply the raw schema to a Postgres/Neon database
psql "$DATABASE_URL" -f db/ga4_schema.sql

# dbt
cd dbt
dbt deps
dbt build            # seeds, models, tests — daily incremental pattern
```

CI needs `DBT_HOST`, `DBT_USER`, `DBT_PASSWORD`, `DBT_DBNAME` as repository secrets (see `.github/workflows/dbt-daily.yml`).

## Data generator

The synthetic GA4 export is produced by a private generator (kept out of this repo): one year of events for 1,000 articles, ~7,600 sessions/quarter, full event taxonomy (`page_view`, `session_start`, `first_visit`, `user_engagement`, `scroll`, `share`, `search`, `newsletter_signup`, `bookmark`, `comment`, `video_start/progress/complete`), weekly seasonality, growth trend, breaking-news spikes (election night, finals, market turmoil), holiday dips, and campaign traffic with real UTM/gclid parameters.

*Volume is calibrated to Neon's free-tier storage limit (512 MB per branch) — roughly 110 sessions/day base. Bump `BASE_SESSIONS_PER_DAY` and give the project more storage for a bigger dataset.*