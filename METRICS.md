# Metrics & Dimensions Catalog

**The semantic layer's data catalog for The Meridian Post** — the single source of truth for what every metric and dimension *means* before it gets encoded as [Cube.js](https://cube.dev) YAML (cubes → measures + dimensions). The Cube models are generated from these definitions; if a definition changes, this document changes first.

Status: **v1 — 2026-09-01** · 21 metrics, 20 dimensions.

## Data context (what the catalog is built on)

| Layer | Facts |
|---|---|
| Raw GA4 export (`analytics_3847629104`) | 257,535 events · 42,410 sessions · 3,310 first visits · Apr 2025 → Mar 2026 · 14 event types |
| CMS export (`cms.articles`) | 1,000 articles · 12 authors · 8 sections · published 2025-01-01 → 2026-03-25 · 350–2,400 words |
| CRM export (`cms.users`) | 350 registered accounts · 246 subscribers · tiers: digital-only / basic / premium |
| dbt marts (`ga4_marts`) | sessions, pages, traffic sources, articles daily, reader types, subscription last-touch |

## Conventions

- **User** — a distinct GA4 client identity (`client_key`), anonymous readers included unless a metric says otherwise. Registered accounts additionally carry a `user_id` joined to the CRM.
- **Session** — a GA4 session (`session_key`): starts with `session_start`, ends after 30 minutes of inactivity. Session-scoped fields (geo, device, platform, traffic source) come from the session's first event.
- **Engaged time** — GA4 engagement time: the sum of `engagement_time_msec` carried by `user_engagement` events.
- **Traffic attribution** — session first-click source/medium/campaign (`session_source`, `session_medium`, `session_campaign`), plus the GA4 default channel grouping and the 30-day last-non-direct variant computed by dbt-ga4. Subscription conversions additionally have last-touch attribution (`fct_newsroom__subscription_last_touch`).
- **Periods** — analytics metrics are keyed on **Event Date** (UTC); CRM metrics on registration/subscription date; content inventory on **Publication Date**. Ratios divide the in-period numerator by the in-period denominator of the same slice.
- **Status legend** — ✅ ready in current data · 🧩 needs a data-model extension (generator → dbt → Cube follow-up).

## Metrics

### Audience & engagement

| Metric | Definition | Formula | Source | Status |
|---|---|---|---|---|
| **Active Users** | Distinct users with ≥ 1 tracked event in the period (anonymous included) | `COUNT(DISTINCT client_key)` | `stg_ga4__events` / session marts | ✅ |
| **Sessions** | GA4 sessions started in the period | `COUNT(DISTINCT session_key)` | `dim_ga4__sessions_daily` | ✅ |
| **Pageviews** | `page_view` events in the period | `COUNT(event_name = 'page_view')` | `fct_ga4__pages` | ✅ |
| **Article Pageviews** | `page_view` events on article pages (URL `/article-<id>`) | `SUM(page_views)` | `fct_newsroom__articles_daily` | ✅ |
| **Avg Engaged Time per User** | Engaged seconds per active user in the period | `SUM(engagement_time_msec) / 1000 ÷ Active Users` | events + session marts | ✅ |
| **Avg Engaged Time per Session** | Engaged seconds per session in the period | `SUM(engagement_time_msec) / 1000 ÷ Sessions` | `fct_newsroom__traffic_sources_daily` | ✅ |
| **Pageviews per User** | Article consumption intensity per user | `Pageviews ÷ Active Users` | derived | ✅ |
| **Pageviews per Session** | Pages viewed per session (GA4 "pages/session") | `Pageviews ÷ Sessions` | derived | ✅ |
| **Sessions per User** | Visit frequency per user in the period | `Sessions ÷ Active Users` | derived | ✅ |

Notes:
- *Active Users* counts any-event users. The stricter GA4 refinement — users with ≥ 1 **engaged** session — is also computable (`is_session_engaged`); we ship any-event as the headline and can expose `Engaged Users` alongside.
- Today **Pageviews = Article Pageviews** (86,622): the generator only emits article pages. The definitions stay distinct — homepage/section views will appear if the generator later emits them.

### Reader growth & subscriptions

| Metric | Definition | Formula | Source | Status |
|---|---|---|---|---|
| **Active Registered Users** | Registered accounts (incl. subscribers) with ≥ 1 event in the period | `COUNT(DISTINCT user_id)` ∩ CRM | events ⋈ `cms.users` | ✅ |
| **Active Subscribers** | Subscribers with ≥ 1 event in the period | same, where CRM `is_subscriber` | events ⋈ `cms.users` | ✅ |
| **New Registered Users** | Accounts whose `registration_date` falls in the period | `COUNT(*)` on `cms.users` | `cms.users` | ✅ |
| **New Subscribers** | Accounts whose `subscription_date` falls in the period — 1:1 with `subscribe` events | `COUNT(*)` on `cms.users` ≡ `COUNT(subscribe)` | `cms.users` / `fct_newsroom__subscription_last_touch` | ✅ |
| **Number of Registered Users** | Cumulative accounts registered as of period end | `COUNT(*) WHERE registration_date <= period_end` | `cms.users` | ✅ |
| **Number of Subscribers** | Cumulative subscribers as of period end | `COUNT(*) WHERE subscription_date <= period_end` | `cms.users` | ✅ |
| **New Churns** | Subscriptions cancelled in the period | `COUNT(*) WHERE churn_date IN period` | `cms.users` | 🧩 |

Notes:
- *New Subscribers* is available both CRM-side (date grain) and GA4-side (`subscribe` event → exact timestamp, purchase session, attribution). The GA4 side powers the source/device/geo slices.
- **Churn gap:** the CRM has no cancellation concept yet. Adding `churn_date` makes *New Churns* a count in period and makes *Active/Number of Subscribers* churn-aware (active = subscribed ≤ end AND not churned by end). Optional GA4 `churn` event if we want churn in the event stream too.
- *Active Registered/Subscribers* deliberately mirror the reader-type lens (anonymous / registered / subscriber) used by `fct_newsroom__articles_daily_by_reader_type`.

### Content

| Metric | Definition | Formula | Source | Status |
|---|---|---|---|---|
| **Number of Articles Published** | Articles with publication date in the period | `COUNT(*) WHERE published_at::date IN period` | `cms.articles` | ✅ |
| **Number of Articles** | Total published inventory as of period end | `COUNT(*) WHERE published_at <= period_end` | `cms.articles` | ✅ |

### Paywall funnel

| Metric | Definition | Formula | Source | Status |
|---|---|---|---|---|
| **Paywall Impressions** | Times the paywall screen was served to a reader | `COUNT(paywall_impression)` | new event | 🧩 |
| **Paywall Clicks** | Clicks on the paywall's subscribe CTA | `COUNT(paywall_click)` | new event | 🧩 |
| **Paywall Conversion Rate** | New Subscribers ÷ Paywall Clicks in the period (companion: Paywall CTR = Clicks ÷ Impressions) | ratio | derived | 🧩 |

**Paywall gap:** the event stream jumps from reading to `subscribe` — there is no paywall surface today (impressions/clicks), and `subscribe` carries no paywall variant. Proposed generator extension: `paywall_impression` and `paywall_click` events on paywalled article hits, both carrying `article_id`, `paywall_type`, `bundle_offer` params (and `subscribe` gaining the same two params). That single change unlocks Paywall Impressions, Paywall Clicks, Paywall Conversion Rate **and** the Paywall Type / Bundle Offer dimensions.

## Dimensions

| Dimension | Definition | Source | Values in the demo |
|---|---|---|---|
| **Country** | Reader geo country (session/event); CRM country for account metrics | `geo.country` · `cms.users.country` | US, United Kingdom, Canada, Australia, Germany, France, India, Singapore, Hong Kong, Japan, Brazil, Netherlands, … |
| **Platform** | GA4 platform | `events.platform` | `web` (only) |
| **Section** | CMS section of the article | `cms.articles.section` | business, culture, lifestyle, opinion, politics, sports, tech, world |
| **Traffic Source** | Session first-click source | `dim_ga4__sessions_daily.session_source` | (direct), google, reddit, x, facebook, mailchimp, themeridianpost, flipboard.com, newsnow.co.uk |
| **Source Medium** | Session first-click medium | `session_medium` | (none), organic, social, cpc, email, app-push, referral |
| **Device** | Device category | `device_category` | desktop, mobile, tablet |
| **Device OS** | Operating system | `device_operating_system` | Windows, Macintosh, iOS, Android, iPadOS |
| **Url** | Full page URL | `fct_ga4__pages.page_location` | `https://www.themeridianpost.com/<section>/article-<id>` |
| **Article ID** | CMS article identifier | `article_id` · `cms.articles` | 1–1000 |
| **Title** | Article title | `cms.articles.title` (matches `page_title` on `page_view`) | |
| **Publication Date** | Article publish date | `cms.articles.published_at` | 2025-01-01 → 2026-03-25 |
| **Event Date** | Analytics date, UTC — the default time grain | `event_date_dt` / `session_partition_date` | 2025-04-01 → 2026-03-31 |
| **Word Count** | Article word count | `cms.articles.word_count` | 350–2,400 |
| **Author** | Article author | `cms.articles.author` | 12 authors |
| **UTM Campaign** | `utm_campaign` captured on the session | `session_campaign` | weekly-digest, morning-brief, breaking-alert, morning-push, breaking-push, news-keywords, brand-awareness, subscription-drive, (none) |
| **UTM Content** | `utm_content` captured on the session | `session_content` | wired end-to-end but ⚠️ the generator emits utm_source/medium/campaign/term only → `(none)` everywhere |
| **Event Name** | Raw GA4 event name (event-level exploration) | `stg_ga4__events.event_name` | page_view, user_engagement, scroll, session_start, video_progress, video_start, share, first_visit, bookmark, comment, search, video_complete, newsletter_signup, subscribe |
| **Paywall Type** | Paywall variant shown | `paywall_impression`/`paywall_click` param | 🧩 proposed: hard, metered |
| **Bundle Offer** | Offer bundle presented on the paywall | same param | 🧩 proposed: tier-aligned (digital-only, basic, premium) or promo bundles |

**Dimension applicability** (rules of thumb):

- Event/session metrics (Active Users → Sessions per User) slice by the session dimensions: Country, Platform, Device, Device OS, Traffic Source, Source Medium, UTM Campaign, Event Date.
- Content metrics (Article Pageviews) additionally slice by Url, Article ID, Title, Author, Section, Word Count, Publication Date.
- CRM metrics (New/Cumulative Registered & Subscribers) slice by Country (CRM), tier, and their own date grains; *New Subscribers* also inherits last-touch attribution dimensions (purchase-session source/medium/platform/device/geo).
- Paywall funnel metrics slice by Event Date + the article dimensions + Paywall Type + Bundle Offer.

## Also available (beyond the v1 list)

- **Default Channel Grouping** — GA4 channel (Direct, Paid Search, Organic Search, Email, Social, Push, Referral), session first-click and 30-day last-non-direct variants.
- **Reader Type** — anonymous / registered / subscriber per event (`fct_newsroom__articles_daily_by_reader_type`), with **Subscription Tier** (digital-only, basic, premium).
- **Article engagement** — scroll depth, video starts/completes, shares, bookmarks, comments, newsletter signups per article.
- **Session context** — landing page, referrer, browser.
- **Subscription last-touch** — conversion path (first-session / same-session / later-session), paywall article, days since last read, purchase-session channel/device/geo.

## Planned Cube mapping (Cube.js YAML)

| Cube | Base model | Carries | Key dimensions |
|---|---|---|---|
| `events` | `stg_ga4__events` | Event Name analysis, raw event counts, paywall funnel (phase 2) | Event Name, Event Date, Url |
| `sessions` | `dim_ga4__sessions_daily` ⋈ `fct_ga4__sessions_daily` | Active Users, Sessions, Pageviews, engaged time, the per-user/per-session ratios | Country, Platform, Device, Device OS, Traffic Source, Source Medium, UTM Campaign, Event Date |
| `pages` | `fct_ga4__pages` | Pageviews | Url, Event Date |
| `articles` | `fct_newsroom__articles_daily` ⋈ `cms.articles` | Article Pageviews + article engagement | Article ID, Title, Author, Section, Word Count, Publication Date, Event Date |
| `readerTypes` | `fct_newsroom__articles_daily_by_reader_type` | Article Pageviews split by Reader Type / Tier | Reader Type, Subscription Tier + article dimensions |
| `traffic` | `fct_newsroom__traffic_sources_daily` | Sessions, Pageviews, engaged time by channel | Channel Grouping, Traffic Source, Source Medium, Event Date |
| `subscriptions` | `fct_newsroom__subscription_last_touch` | New Subscribers + last-touch attribution | Traffic Source, Source Medium, Platform, Device, Country, Tier, Event Date |
| `crm` | `cms.users` | New Registered Users, New Subscribers, Number of…, New Churns (phase 2) | Country, Tier |
| `content` | `cms.articles` | Number of Articles Published, Number of Articles | Section, Author, Publication Date, Word Count |
| `paywall` (phase 2) | paywall events mart | Paywall Impressions, Clicks, Conversion Rate | Paywall Type, Bundle Offer + article dimensions |

## Open definitional questions

1. **Paywall events** — extend the generator with `paywall_impression` + `paywall_click` (params: `article_id`, `paywall_type`, `bundle_offer`, mirrored on `subscribe`)? Proposed variants: `hard` / `metered`; bundles tier-aligned or promo-named.
2. **Paywall Conversion Rate** — New Subscribers ÷ Paywall Clicks (proposed), or ÷ Paywall Impressions? (CTR = Clicks ÷ Impressions ships as the companion either way.)
3. **Churn** — add `churn_date` to the CRM (definition above)? Optional GA4 `churn` event in the stream?
4. **Active Subscribers / Active Registered Users** — defined as *active in period* (≥ 1 event), mirroring the reader-type lens. Alternative: end-of-period status snapshot. Confirm?
5. **UTM Content** — keep as-is (wired, currently always `(none)`) or have the generator emit `utm_content` variants so the dimension has data?