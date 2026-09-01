# Metrics & Dimensions Catalog

**The semantic layer's data catalog for The Meridian Post** — the single source of truth for what every metric and dimension *means* before it gets encoded as [Cube.js](https://cube.dev) YAML (cubes → measures + dimensions). The Cube models are generated from these definitions; if a definition changes, this document changes first.

Status: **v1.2 — 2026-09-01** · 21 metrics, 22 dimensions — paywall + churn shipped in the data.

## Data context (what the catalog is built on)

| Layer | Facts |
|---|---|
| Raw GA4 export (`analytics_3847629104`) | 204,388 events · 42,117 sessions · 3,323 first visits · Apr 2025 → Mar 2026 · 16 event types |
| CMS export (`cms.articles`) | 1,000 articles · 12 authors · 8 sections · published 2025-01-01 → 2026-03-25 · 350–2,400 words |
| CRM export (`cms.users`) | 350 registered accounts · 256 subscribers (204 active · 52 churned) · tiers: digital-only / basic / premium |
| dbt marts (`ga4_marts`) | sessions, pages, traffic sources, articles daily, reader types, subscription last-touch, paywall funnel (daily + exposed sessions) |

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
- Today **Pageviews = Article Pageviews** (70,373): the generator only emits article pages. The definitions stay distinct — homepage/section views will appear if the generator later emits them.

### Reader growth & subscriptions

| Metric | Definition | Formula | Source | Status |
|---|---|---|---|---|
| **Active Registered Users** | Registered accounts (incl. subscribers) with ≥ 1 event in the period | `COUNT(DISTINCT user_id)` ∩ CRM | events ⋈ `cms.users` | ✅ |
| **Active Subscribers** | Subscribers with ≥ 1 event in the period | same, where the subscription is active in period (churn-aware once `churn_date` lands) | events ⋈ `cms.users` | ✅ |
| **New Registered Users** | Accounts whose `registration_date` falls in the period | `COUNT(*)` on `cms.users` | `cms.users` | ✅ |
| **New Subscribers** | Accounts whose `subscription_date` falls in the period — 1:1 with `subscribe` events | `COUNT(*)` on `cms.users` ≡ `COUNT(subscribe)` | `cms.users` / `fct_newsroom__subscription_last_touch` | ✅ |
| **Number of Registered Users** | Cumulative accounts registered as of period end | `COUNT(*) WHERE registration_date <= period_end` | `cms.users` | ✅ |
| **Number of Subscribers** | Active subscriptions as of period end (churn-aware) | `COUNT(*) WHERE subscription_date <= period_end AND (churn_date IS NULL OR churn_date > period_end)` | `cms.users` | ✅ |
| **New Churns** | Subscriptions cancelled in the period | `COUNT(*) WHERE churn_date IN period` | `cms.users` | ✅ |

Notes:
- *New Subscribers* is available both CRM-side (date grain) and GA4-side (`subscribe` event → exact timestamp, purchase session, attribution). The GA4 side powers the source/device/geo slices.
- **Churn (shipped):** `churn_date` on the CRM — 52 of 256 subscribers cancelled (May 2025 → Mar 2026, each ≥ 1 billing cycle after subscribing). *New Churns* counts cancellations in period; *Active/Number of Subscribers* are churn-aware; churned readers classify as 'registered' from their churn date. Churn stays CRM-side (no GA4 churn event).
- *Active Registered/Subscribers* deliberately mirror the reader-type lens (anonymous / registered / subscriber) used by `fct_newsroom__articles_daily_by_reader_type`.

### Content

| Metric | Definition | Formula | Source | Status |
|---|---|---|---|---|
| **Number of Articles Published** | Articles with publication date in the period | `COUNT(*) WHERE published_at::date IN period` | `cms.articles` | ✅ |
| **Number of Articles** | Total published inventory as of period end | `COUNT(*) WHERE published_at <= period_end` | `cms.articles` | ✅ |

### Paywall funnel

**Paywall model (shipped):** two wall variants, both enforced as hard blocks on the article. Non-subscribers get **3 free article reads per calendar month** — from the 4th onward, metered sections serve the wall (`paywall_type = 'metered'`). Premium sections are walled on **every** non-subscriber read, no free allowance (`paywall_type = 'hard'`). One section is never walled (lifestyle). Subscribers never see a paywall. Every wall carries the `bundle_offer` shown — tier-aligned: digital-only / basic / premium — mirrored on the subsequent `subscribe`.

| Metric | Definition | Formula | Source | Status |
|---|---|---|---|---|
| **Paywall Impressions** | Times a paywall was served to a non-subscriber (blocked article hit) | `COUNT(paywall_impression)` | `fct_newsroom__paywall_daily` | ✅ |
| **Paywall Clicks** | Clicks on the paywall's subscribe CTA | `COUNT(paywall_click)` | `fct_newsroom__paywall_daily` | ✅ |
| **Paywall Conversion Rate** | New Subscribers ÷ sessions exposed to the paywall in the period | `New Subscribers ÷ COUNT(rows: fct_newsroom__paywall_sessions_daily)` | derived | ✅ |

Companion ratio: **Paywall CTR** = Paywall Clicks ÷ Paywall Impressions. Both ratios break down by Paywall Type and Bundle Offer — *which wall converts* is the dashboard story.

**In the demo year:** 31,977 impressions (hard 26,899 · metered 5,078) → 1,614 clicks (CTR 5.1%: hard 4.7% · metered 7.0%) → 256 subscribers across 25,615 paywall-exposed sessions — **1.0% session conversion rate**. Every conversion runs the full funnel: impression → click → subscribe in the same session, bundle shown = tier bought.

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
| **Registration Date** | CRM account registration date — the time grain for reader-growth metrics | `cms.users.registration_date` | 2025-04-12 → 2026-03-01 |
| **Subscription Date** | Subscription start date — the time grain for subscription metrics | `cms.users.subscription_date` | 2025-04-12 → 2026-03-20 |
| **Word Count** | Article word count | `cms.articles.word_count` | 350–2,400 |
| **Author** | Article author | `cms.articles.author` | 12 authors |
| **UTM Campaign** | `utm_campaign` captured on the session | `session_campaign` | weekly-digest, morning-brief, breaking-alert, morning-push, breaking-push, news-keywords, brand-awareness, subscription-drive, (none) |
| **UTM Content** | `utm_content` captured on the session | `session_content` | hero-article, top-story, footer-link (email) · ad-variant-a, ad-variant-b (cpc) · push-banner, deep-link (app-push); `(none)` for untagged sessions |
| **Event Name** | Raw GA4 event name (event-level exploration) | `stg_ga4__events.event_name` | page_view, user_engagement, scroll, session_start, video_progress, video_start, share, first_visit, bookmark, comment, search, video_complete, newsletter_signup, subscribe |
| **Paywall Type** | Wall variant served | `paywall_impression`/`paywall_click` param | hard (business, politics, world — always walled) · metered (culture, opinion, sports, tech — after 3 free reads/month); lifestyle never walled |
| **Bundle Offer** | Offer bundle presented on the paywall | same param | tier-aligned: digital-only, basic, premium |

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
| `crm` | `cms.users` | New Registered Users, New Subscribers, Number of…, New Churns | Country, Tier, Registration Date, Subscription Date |
| `content` | `cms.articles` | Number of Articles Published, Number of Articles | Section, Author, Publication Date, Word Count |
| `paywall` | `fct_newsroom__paywall_daily` ⋈ `fct_newsroom__paywall_sessions_daily` | Paywall Impressions, Clicks, CTR, sessions exposed (the conversion-rate denominator) | Paywall Type, Bundle Offer + article dimensions |

## Decisions (2026-09-01)

1. **Paywall model** — hard + metered walls: 3 free article reads per calendar month, the 4th hit onward always walled; `paywall_type` = hard / metered; one section free (lifestyle); `bundle_offer` tier-aligned.
2. **Paywall Conversion Rate** — New Subscribers ÷ sessions with ≥ 1 paywall impression (Paywall CTR = clicks ÷ impressions as companion).
3. **Churn** — CRM `churn_date`; New Churns = cancellations in period; subscriber counts churn-aware.
4. **Active Registered Users / Active Subscribers** — active in the selected event-date period (≥ 1 event).
5. **Reader-growth time grains** — Registration Date and Subscription Date added as CRM time dimensions.

## Still open

Nothing blocking — both open items shipped with the 2026-09-01 generator v2:

- **Section → wall mapping** — shipped as proposed: hard = business, politics, world · metered = culture, opinion, sports, tech · free = lifestyle.
- **UTM Content** — generator now emits `utm_content` variants on campaign landings (7 values across email / cpc / push).