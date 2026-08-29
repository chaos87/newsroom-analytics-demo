# Data Model — GA4-Compatible by Design

The schema for this demo isn't a generic web-analytics setup. It deliberately mirrors how **Google Analytics 4** structures its export, so anyone who has worked with GA4 data feels at home immediately — same concepts, same attribution conventions, same quirks.

## Why GA4-compatible?

GA4's event model is now the de-facto standard for web analytics. If a demo data model uses GA4 conventions, it answers real questions analytics teams actually ask:

- "How do I define a *session* without a session table?"
- "What's the difference between a pageview and an event?"
- "How do I handle `(direct) / (none)` traffic honestly?"
- "Where do engagement time and scroll depth live?"

## Layer by layer

```
┌──────────────────────────── RAW LAYER ────────────────────────────┐
│                                                                   │
│   pageviews  ◄── one row per page_view event                     │
│   events     ◄── all other interactions (scroll, share, …)       │
│                                                                   │
├────────────────────────── DIMENSIONS ─────────────────────────────┤
│                                                                   │
│   users      ◄── visitor identity + device/geo attributes        │
│   articles   ◄── the content being measured                       │
│                                                                   │
├───────────────────────── REPORTING LAYER ─────────────────────────┤
│                                                                   │
│   daily_metrics          ◄── per (date × article) rollup         │
│   traffic_source_daily   ◄── per (date × source × medium) rollup  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## How it maps to GA4

| This schema | GA4 export equivalent | Notes |
|---|---|---|
| `pageviews.event_id` | `event_id` | One row per `page_view` event |
| `pageviews.session_id` | `ga_session_id` (event param) | Sessions derived from IDs, not a session table — same as GA4 |
| `events.event_name` | `event_name` | `scroll`, `video_start`, `share`, `newsletter_signup`, `paywall_hit`, … |
| `events.event_params` | `event_params` (RECORD array) | GA4 nests params in a repeated record; flattened here into `jsonb` |
| `pageviews.source` / `medium` | `session_source` / `session_medium` | Attribution on the fact row, denormalized for fast queries |
| `users.anonymous_id` | `user_pseudo_id` (client_id) | First-party cookie/ID equivalent |
| `pageviews.is_new_user` | derived (`session_number = 1` in GA4) | Pre-computed here for reporting convenience |
| `pageviews.engagement_time_msec` | `engagement_time_msec` event param | Same metric, same unit |
| `pageviews.scroll_depth_pct` | derived from `scroll` event (percent = 90) | Continuous value instead of GA4's fixed-threshold event |

### Attribution defaults

GA4 uses specific sentinel values for unattributed traffic. The schema follows the same convention:

- **`(direct) / (none)`** — no referrer available (the honest majority of direct traffic)
- **`meridianpost / app-push`** — push notification opens from the mobile app (equivalent to GA4's mobile-app traffic via a custom source)

## Design decisions worth calling out

1. **No session table.** Sessions are derived from `session_id` on fact rows — matching GA4's approach, where "sessions" are computed properties, not stored entities. This keeps ingestion simple and makes session definitions a *modeling* decision (dbt/Cube) rather than a locked-in schema decision.

2. **Pageviews split from events.** In GA4 everything is an event, and `page_view` is just one event name. Splitting it out is a deliberate denormalization: pageviews are ~10× more frequent than other events, get queried far more, and carry extra columns (`device_category`, `scroll_depth_pct`) that other events don't need.

3. **Aggregates exist for a reason.** `daily_metrics` and `traffic_source_daily` aren't premature optimization — they're the pattern you'd use when a dashboard hits raw event tables directly (the classic "dashboards are slow" problem). The raw layer stays authoritative; the aggregates are rebuildable.

4. **`is_new_user` precomputed on the fact row.** GA4 makes you derive "new user" from `session_number = 1`. Storing it at event time is cheaper at query time and makes cohort-style analyses trivial — at the cost of being technically derivable. A trade worth making in a demo where the dashboard needs to be snappy.

## Traffic sources in the demo dataset

| source | medium | What it represents |
|---|---|---|
| `(direct)` | `(none)` | Direct traffic — the majority, as in real newsrooms |
| `google` | `organic` | Search |
| `news.google.com` | `referral` | Google News surface |
| `facebook` / `x` / `reddit` | `social` | Social media |
| `mailchimp` | `email` | Newsletter clicks |
| `meridianpost` | `app-push` | Mobile push notifications |
| `google` | `cpc` | Paid (Google Ads) |
| `partner-site` | `referral` | Referrals from other sites |

## Dataset shape

30 days of data: ~240 articles across 8 sections, ~1,500 users, ~12k pageviews, ~9k events — enough volume for meaningful aggregates, small enough for fast demo queries.