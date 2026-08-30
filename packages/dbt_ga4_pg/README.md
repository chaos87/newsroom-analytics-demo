# dbt-ga4 for PostgreSQL (vendored port)

This is a vendored, Postgres-portable fork of **[Velir/dbt-ga4](https://github.com/Velir/dbt-ga4)** (upstream v6.2.0, MIT License, © Adam Ribaudo / Velir). It is included as a local dbt package so the transformation layer stays fully visible in this repo.

All credit for the model design, sessionization logic, attribution window semantics, and default channel grouping belongs to the upstream authors. This port changes only what BigQuery-isms required.

## Why a port?

The upstream package targets the GA4 **BigQuery** export. The Meridian Post demo runs the same GA4 export *shape* on **PostgreSQL (Neon)** — one natively-partitioned `events` table with `events_YYYYMMDD` partitions and nested `RECORD` columns stored as JSONB — so the package's models needed a dialect port.

## Ported scope (the daily / incremental core)

- `base_ga4__events` — source columns, typed casts, dedup by event identity (upstream: incremental insert_overwrite; port: **view** — native table partitioning already provides what the BQ base table exists for, and it saves a full copy of the events data)
- `stg_ga4__events` — client/session/event keys, URL parsing, gclid detection
- Event stagings: `page_view`, `session_start`, `first_visit`, `user_engagement`, `scroll`, `video_start`, `video_progress` **(port addition)**, `video_complete`, `search`, `share` (+ `click`, `file_download`, `view_search_results` kept from upstream)
- Attribution: `stg_ga4__sessions_traffic_sources_daily` + `stg_ga4__sessions_traffic_sources_last_non_direct_daily` (configurable lookback via `session_attribution_lookback_window_days`, default 30)
- `stg_ga4__session_conversions_daily`, `stg_ga4__page_conversions`, `stg_ga4__page_engaged_time`
- User layer: `stg_ga4__user_id_mapping`, `stg_ga4__user_properties`, `stg_ga4__client_key_first_last_events`, `stg_ga4__client_key_first_last_pageviews`
- Marts: `dim_ga4__sessions_daily`, `fct_ga4__sessions_daily`, `fct_ga4__sessions`, `fct_ga4__pages`, `dim_ga4__client_keys`, `fct_ga4__client_keys`, `fct_ga4__user_ids`

Not ported (not applicable to a publisher demo on Postgres): e-commerce / items models, GA4 user-export tables (`users_*`, `pseudonymous_users_*`), multi-property combining, non-daily `dim_ga4__sessions` / `stg_ga4__sessions_traffic_sources`, derived user/session property models.

## Translation table

| BigQuery (upstream) | PostgreSQL (this port) |
|---|---|
| `events_*` wildcard + `_table_suffix` filters | single `events` table, `event_date` ('YYYYMMDD' text) filters with native partition pruning |
| `UNNEST(event_params)` scalar subqueries | `jsonb_array_elements(...)` with typed `->>` casts (`unnest_key` macro) |
| `RECORD` field paths (`device.category`, ...) | `->>`/`->` JSONB extraction (`base_select` macros) |
| `insert_overwrite` + `partition_by` configs | incremental `delete+insert` with `unique_key`, same `current_date − static_incremental_days` window (GA4's 3-day late-arrival pattern) |
| `to_base64(md5(...))` surrogate keys | `md5(...)` |
| `QUALIFY row_number() = 1` | `row_number()` in a CTE + `WHERE rn = 1` |
| `FIRST_VALUE(...) IGNORE NULLS` | `DISTINCT ON (...) ORDER BY` (attribution models) / `array_agg(... ORDER BY)` (first/last events) / `max(...) FILTER (...)` (last non-direct lookback) |
| `countif(x)`, `ifnull`, `safe_divide` | `count(*) filter (where x)`, `coalesce`, `x / nullif(y, 0)` |
| `REGEXP_CONTAINS(x, r"...")` | `x ~ '...'` |
| `REGEXP_EXTRACT` | `substring(x from '...')` |
| `parse_date('%Y%m%d', d)` | `to_date(d, 'YYYYMMDD')` |
| `split(x, '/')[safe_ordinal(n)]` | `split_part(x, '/', n)` |
| `* except(col)` | explicit column lists |
| `session_engaged` int-or-string handling | kept (coalesce int extract / `'1'` string) |
| `vide_title` param typo (upstream) | fixed to `video_title` |

## Variables

Same as upstream — see the root project's `dbt/dbt_project.yml` for the live configuration (flat/global scope so both package and project models resolve them). Required: `source_project`, `property_ids`, `start_date`, `static_incremental_days`. Notable: `session_attribution_lookback_window_days` (30), `conversion_events`, `user_properties`, `[event]_custom_parameters`.

The `ga4_source_categories` seed and the `default_channel_grouping` macro (Google's channel rules) are carried over unchanged (regex dialect adjusted).

Upstream docs: https://github.com/Velir/dbt-ga4
GA4 export schema: https://support.google.com/analytics/answer/7029846