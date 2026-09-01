# GA4 BigQuery export schema → PostgreSQL emulation notes

The raw layer (`db/ga4_schema.sql`) is a faithful Postgres emulation of the GA4
BigQuery export schema documented at:
<https://support.google.com/analytics/answer/7029846>

## Dataset ↔ schema

| BigQuery | PostgreSQL (Neon) |
|---|---|
| dataset `analytics_<property_id>` | schema `analytics_3847629104` (property 3847629104) |
| daily sharded tables `events_YYYYMMDD` | one `events` table, `PARTITION BY RANGE (event_date)`, **partitions named `events_YYYYMMDD`** |
| intraday tables `events_intraday_*` | not emulated (batch export only) |
| — | `cms` schema: CMS/CRM exports (`articles`, `users`), the business-data join GA4 data gets combined with in every real newsroom stack |

## Type mapping

| BQ type | PG type | Notes |
|---|---|---|
| `event_date` STRING 'YYYYMMDD' | `text` | kept identical — and it works natively as a range partition key (lexicographic = chronological) |
| `event_timestamp` INTEGER (micros UTC) | `bigint` | microsecond timestamps, same epoch semantics |
| `event_params` REPEATED RECORD | `jsonb` | `[{"key": "...", "value": {"string_value": ... , "int_value": ...}}]` — value fields beyond the populated one are omitted (absent ≡ null) |
| `user_properties` REPEATED RECORD | `jsonb` | same shape + `set_timestamp_micros` |
| `device`, `geo`, `app_info`, `privacy_info`, `user_ltv` RECORDs | `jsonb` | nested exactly like the export; null RECORDs stored as NULL |
| `traffic_source` RECORD | `jsonb` | `{source, medium, name}` — **populated only on `session_start` / `first_visit` events**, matching real export behaviour (event-level attribution lives in `source`/`medium` event params instead) |
| `collected_traffic_source` RECORD | `jsonb` | `{manual_source, manual_medium, manual_campaign_name, manual_term, gclid, ...}` on campaign landings (UTM/gclid), absent for direct/organic-referrer hits |
| `session_traffic_source_last_click` RECORD | `jsonb` (NULL) | Google-Ads attribution record; no Ads in this demo |
| `ecommerce`, `items`, `item_params` | `jsonb` (NULL) | publisher site — no commerce events |
| `batch_event_index`, `batch_ordering_id`, `batch_page_id` | `bigint` | newest export fields — event bundling on the device |

## Fidelity behaviours baked into the data

- **`ga_session_id` / `ga_session_number` event params** on every event of a
  session (gtag.js attaches session params to each hit). `ga_session_id` is the
  session start in unix seconds. This is what the dbt-ga4 sessionization reads.
- **`source` / `medium` / `campaign` / `term` / `content` params** only on the landing
  `page_view` of a session (UTM / auto-detected referral), exactly how gtag.js
  collects them. Direct sessions carry no source/medium params (they are
  "(direct)"/"(none)" only as attribution fallbacks downstream).
- **`entrances=1`** on landing page_views.
- **`engagement_time_msec`** on `user_engagement` events; `percent_scrolled`
  on `scroll` events; GA4 media params (`video_*`, `visible`) on the video trio.
- **Consent-denied hits**: ~1.5% of users deny analytics storage → events with
  NULL `user_pseudo_id`, no `ga_session_id`, `privacy_info.analytics_storage='No'`
  (the dbt-ga4 models explicitly handle null client keys for this case).
- **`user_id`** is set on events of logged-in sessions of registered readers;
  `user_properties` (`subscriber_status`, `subscription_tier`) appear on events
  from the account's registration date onward — powering the identity-stitching
  and user-property models in the dbt layer.
- **Paywall events** (`paywall_impression`, `paywall_click`) fire on blocked
  article hits for non-subscribers, carrying `article_id`, `paywall_type`
  (`hard` = premium sections always walled / `metered` = walled after 3 free
  article reads per calendar month; `lifestyle` never walled) and the
  tier-aligned `bundle_offer` shown. The `subscribe` conversion event always
  follows an impression + click in the same session and mirrors both params.
  Walled hits emit a `page_view` but no content events (scroll / engagement /
  video) — the article is blocked.
- **CRM `churn_date`**: subscriptions can cancel (~monthly hazard after the
  first billing cycle); `is_subscriber` in the export is the active-at-export-end
  snapshot, while subscription history stays in `subscription_date` +
  `churn_date`. `user_properties` flip back to `subscriber_status: 'registered'`
  after churn.
- **`user_first_touch_timestamp`** in micros; some users' first visit predates
  the export window (returning visitors), so their first in-window session has
  `ga_session_number > 1`.
- **Late arrival**: GA4 updates daily tables for up to 3 days after the event
  date; the dbt incremental models mirror this by reprocessing a 3-day window
  every run (`static_incremental_days: 3`).