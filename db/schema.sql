-- ═══════════════════════════════════════════════════════════════════════════
-- The Meridian Post — Newsroom Analytics Schema
--
-- A GA4-compatible analytics data model for a fictional digital newspaper.
-- Target platform: PostgreSQL (built and tested on Neon)
--
-- Design notes:
--   * `pageviews` and `events` are the raw fact tables (the "GA4 export" layer)
--   * `users` and `articles` are dimensions
--   * `daily_metrics` and `traffic_source_daily` are pre-aggregated tables
--     (the "reporting" layer — cheaper queries for dashboard hot paths)
--   * Traffic attribution defaults follow GA4 conventions:
--       (direct) / (none) — unattributed traffic
--       meridianpost / app-push — push notifications from the mobile app
-- ═══════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────
-- users — site visitors (anonymous_id plays the role of GA4 client_id)
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE users (
    user_id            SERIAL PRIMARY KEY,
    anonymous_id       text        NOT NULL,
    registration_date  date,
    country            text        DEFAULT 'US',
    device_type        text        DEFAULT 'desktop',
    operating_system   text,
    browser            text,
    is_subscriber      boolean     DEFAULT false,
    subscription_tier  text,
    created_at         timestamptz NOT NULL DEFAULT now()
);

-- ───────────────────────────────────────────────────────────────────────────
-- articles — the content being measured
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE articles (
    article_id    SERIAL       PRIMARY KEY,
    title         text         NOT NULL,
    section       text         NOT NULL DEFAULT 'news',
    author        text,
    published_at  timestamptz  NOT NULL DEFAULT now(),
    word_count    integer      DEFAULT 0,
    is_breaking   boolean      DEFAULT false
);

-- ───────────────────────────────────────────────────────────────────────────
-- pageviews — fact table, one row per page_view event (GA4's core event)
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE pageviews (
    event_id              BIGSERIAL    PRIMARY KEY,
    event_timestamp       timestamptz  NOT NULL DEFAULT now(),
    user_id               integer      REFERENCES users(user_id),
    article_id            integer      REFERENCES articles(article_id),
    session_id            text         NOT NULL,
    page_path             text         NOT NULL,
    page_title            text,
    source                text         DEFAULT '(direct)',
    medium                text         DEFAULT '(none)',
    device_category       text         DEFAULT 'desktop',
    country               text         DEFAULT 'US',
    is_new_user           boolean      DEFAULT false,
    engagement_time_msec  integer      DEFAULT 0,
    scroll_depth_pct      integer      DEFAULT 0
);

CREATE INDEX idx_pageviews_timestamp      ON pageviews (event_timestamp);
CREATE INDEX idx_pageviews_article       ON pageviews (article_id);
CREATE INDEX idx_pageviews_user          ON pageviews (user_id);
CREATE INDEX idx_pageviews_source_medium ON pageviews (source, medium);

-- ───────────────────────────────────────────────────────────────────────────
-- events — fact table for non-pageview interactions
-- (scroll, video_start, share, newsletter_signup, paywall_hit, …)
-- event_params is the flexible GA4-style parameter payload
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE events (
    event_id         BIGSERIAL   PRIMARY KEY,
    event_timestamp  timestamptz NOT NULL DEFAULT now(),
    user_id          integer     REFERENCES users(user_id),
    article_id       integer     REFERENCES articles(article_id),
    session_id       text        NOT NULL,
    event_name       text        NOT NULL,
    event_params     jsonb       DEFAULT '{}',
    source           text        DEFAULT '(direct)',
    medium           text        DEFAULT '(none)'
);

CREATE INDEX idx_events_timestamp ON events (event_timestamp);
CREATE INDEX idx_events_article   ON events (article_id);
CREATE INDEX idx_events_name      ON events (event_name);

-- ───────────────────────────────────────────────────────────────────────────
-- daily_metrics — pre-aggregated per (date × article), the reporting layer
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE daily_metrics (
    date                     date     NOT NULL,
    article_id               integer  NOT NULL REFERENCES articles(article_id),
    pageviews                integer  DEFAULT 0,
    unique_users             integer  DEFAULT 0,
    new_users                integer  DEFAULT 0,
    avg_engagement_time_msec integer  DEFAULT 0,
    avg_scroll_depth_pct     integer  DEFAULT 0,
    PRIMARY KEY (date, article_id)
);

-- ───────────────────────────────────────────────────────────────────────────
-- traffic_source_daily — pre-aggregated per (date × source × medium)
-- mirrors GA4's session_source / session_medium attribution
-- ───────────────────────────────────────────────────────────────────────────
CREATE TABLE traffic_source_daily (
    date          date     NOT NULL,
    source        text     NOT NULL,
    medium        text     NOT NULL,
    pageviews     integer  DEFAULT 0,
    unique_users  integer  DEFAULT 0,
    new_users     integer  DEFAULT 0,
    PRIMARY KEY (date, source, medium)
);