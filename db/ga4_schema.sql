-- ═══════════════════════════════════════════════════════════════════════════
-- The Meridian Post — Raw data layer
--
-- Emulates the GA4 BigQuery export on PostgreSQL (Neon).
-- Reference schema: https://support.google.com/analytics/answer/7029846
--
-- Real GA4 exports one daily sharded table (events_YYYYMMDD) per day into a
-- BigQuery dataset named analytics_<property_id>. On PostgreSQL we emulate:
--   * dataset  analytics_<property_id>  → schema analytics_3847629104
--   * sharded daily tables              → one `events` table, natively
--     partitioned by day, with partitions named events_YYYYMMDD (identical
--     to GA4's daily table names)
--   * nested RECORD columns              → JSONB (event_params, user_properties,
--     device, geo, traffic_source, ...)
--   * event_date stays a 'YYYYMMDD' string (BQ STRING type), exactly like the
--     export — and it works natively as a Postgres range partition key.
--
-- The CMS export (articles) and the CRM export (users) live in schema `cms`:
-- a classic newsroom stack joins GA4 analytics against CMS/CRM data.
--
-- Teardown of the previous custom schema (v1 of this demo) is included below
-- and is idempotent.
-- ═══════════════════════════════════════════════════════════════════════════

-- Previous v1 tables (custom schema, superseded by the GA4 export shape) ----
DROP TABLE IF EXISTS public.daily_metrics CASCADE;
DROP TABLE IF EXISTS public.traffic_source_daily CASCADE;
DROP TABLE IF EXISTS public.pageviews CASCADE;
DROP TABLE IF EXISTS public.events CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.articles CASCADE;

CREATE SCHEMA IF NOT EXISTS analytics_3847629104;
CREATE SCHEMA IF NOT EXISTS cms;

-- ─── CMS export ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cms.articles (
    article_id    integer     PRIMARY KEY,
    title         text        NOT NULL,
    section       text        NOT NULL,
    author        text        NOT NULL,
    published_at  timestamptz NOT NULL,
    word_count    integer     NOT NULL,
    is_breaking   boolean     NOT NULL DEFAULT false,
    has_video     boolean     NOT NULL DEFAULT false
);

-- ─── CRM export (accounts & subscriptions) ──────────────────────────────────
-- `user_id` is the login id sent as GA4 `user_id`; `user_pseudo_id` is the
-- first known GA4 client id for that account.
CREATE TABLE IF NOT EXISTS cms.users (
    user_id            text  PRIMARY KEY,
    user_pseudo_id     text,
    registration_date  date  NOT NULL,
    country            text,
    is_subscriber      boolean NOT NULL DEFAULT false,
    subscription_tier  text
);

-- ─── GA4 events export (events_YYYYMMDD tables) ────────────────────────────
-- Column set mirrors the GA4 BigQuery export "events" table:
--   https://support.google.com/analytics/answer/7029846#tables
-- REPEATED RECORD / RECORD columns are stored as JSONB:
--   event_params:      [{"key": "...", "value": {"string_value": "...", "int_value": null, ...}}]
--   user_properties:  [{"key": "...", "value": {"string_value": "...", "set_timestamp_micros": ...}}]
--   device:            {"category": "mobile", "operating_system": "iOS", "web_info": {...}, ...}
--   geo:               {"continent": "...", "country": "...", "region": "...", ...}
--   traffic_source:    {"source": "...", "medium": "...", "name": "..."}   (session-scoped, like GA4)
--   collected_traffic_source: {"manual_source": "...", "manual_medium": "...", "gclid": "..."}
CREATE TABLE IF NOT EXISTS analytics_3847629104.events (
    event_date                        text    NOT NULL,   -- 'YYYYMMDD' (BQ STRING)
    event_timestamp                   bigint  NOT NULL,   -- microseconds, UTC
    event_name                       text    NOT NULL,
    event_params                     jsonb,               -- REPEATED RECORD
    event_previous_timestamp          bigint,
    event_value_in_usd                double precision,
    event_bundle_sequence_id          bigint,
    event_server_timestamp_offset     integer,
    batch_event_index                 bigint,
    batch_ordering_id                 bigint,
    batch_page_id                     bigint,
    is_active_user                    boolean,
    user_id                           text,
    user_pseudo_id                    text,
    privacy_info                      jsonb,
    user_properties                   jsonb,               -- REPEATED RECORD
    user_first_touch_timestamp        bigint,
    user_ltv                          jsonb,
    device                            jsonb,
    geo                               jsonb,
    app_info                          jsonb,
    traffic_source                    jsonb,
    stream_id                        text    NOT NULL,
    platform                          text,
    ecommerce                         jsonb,
    items                             jsonb,               -- REPEATED RECORD
    item_params                       jsonb,               -- REPEATED RECORD
    collected_traffic_source          jsonb,
    session_traffic_source_last_click jsonb
) PARTITION BY RANGE (event_date);

-- No secondary indexes at this scale: every dbt query prunes to day partitions
-- via the event_date key, and Neon's storage budget leaves no room for index copies.

-- Daily partitions, named exactly like GA4's daily tables: events_YYYYMMDD.
-- (GA4 also keeps 3 days of late-arriving updates — our dbt incremental models
-- reprocess a 3-day window to mirror that behaviour.)
DO $$
DECLARE
    d date := date '2025-04-01';
BEGIN
    WHILE d <= date '2026-03-31' LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS analytics_3847629104.events_%s PARTITION OF analytics_3847629104.events FOR VALUES FROM (%L) TO (%L)',
            to_char(d, 'YYYYMMDD'), to_char(d, 'YYYYMMDD'), to_char(d + 1, 'YYYYMMDD')
        );
        d := d + 1;
    END LOOP;
END $$;