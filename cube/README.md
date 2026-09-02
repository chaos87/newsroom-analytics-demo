# Semantic Layer (Cube.js)

The METRICS.md catalog encoded as [Cube.js](https://cube.dev) YAML data models over the dbt marts — one consistent API for every metric and dimension in the demo. Point it at the Neon database running the dbt layer and every newsroom question becomes a single query.

Same infrastructure pattern as the spotistats Cube.js service: a Docker container running `cubejs-server` on port 4000, deployed to Cloud Run — **no Cube Store** (no pre-aggregations; in-process memory cache).

## Cubes

| Cube | Carries | Grain |
|---|---|---|
| `events` | Event Name analysis; Active Users, Active Registered Users, Active Subscribers (active-in-period, churn-aware) | GA4 event |
| `sessions` | Sessions, Pageviews, engaged time, per-user / per-session ratios; geo / device / platform / traffic-source dimensions | GA4 session |
| `pages` | Pageviews by URL | page · day |
| `articles` | Article Pageviews + engagement (scroll, video, shares, bookmarks, comments, newsletter signups) | article · day |
| `readerTypes` | Article Pageviews split by reader type / subscription tier | article · reader type · day |
| `traffic` | Sessions, Pageviews, engaged time, Newsletter Signups by channel grouping + first-click / last-non-direct source | GA4 session |
| `subscriptions` | New Subscribers with last-touch attribution (purchase-session channel, device, geo, paywall article) | subscription |
| `crm` | New Registered Users, New Subscribers, New Churns | CRM account |
| `crmTotals` | Number of Registered Users, Number of Subscribers, Cumulative Subscribers / Churns — state as of the period end | as-of day |
| `content` | Number of Articles Published | article |
| `contentTotals` | Number of Articles (cumulative inventory) | as-of day |
| `paywall` | Paywall Impressions / Clicks / CTR by wall type + bundle offer | article · wall type · bundle · day |
| `paywallSessions` | Sessions with ≥ 1 paywall impression — the conversion-rate denominator | session · day |
| `paywallFunnel` | The full funnel at day grain: exposed sessions → clicks → same-day subscribers; **Paywall Conversion Rate** | day |

**Paywall Conversion Rate** = New Subscribers ÷ sessions with ≥ 1 paywall impression, per METRICS.md. The `paywallFunnel` cube computes both sides at a shared date grain so the ratio is a first-class measure.

**Consistency notes**

- `traffic` reads the session grain (`dim_ga4__sessions_daily ⋈ fct_ga4__sessions_daily`) with `countDistinct(session_key)` measures, so **Sessions = 42,117 everywhere**. The pre-aggregated traffic mart counts session-partition-days (42,135) — midnight-spanning sessions appear twice when summed.
- **638 page_view hits (0.9%) have no client/session key** (a generator artifact): they count in `pages`, `articles` and `readerTypes` (70,373 Pageviews) but cannot be attributed to sessions — `sessions`/`traffic` pageviews are 69,735.
- Cumulative metrics live in the `crmTotals` / `contentTotals` cubes: a generated day-spine with the state as of each date. `max` measures pick the period-end value for monotonic totals; `numberOfSubscribers` takes the value on the **latest as-of date** (it is not monotonic — churns pull it down, so a max would report the peak, not the end state).

## Run it locally

```bash
cp .env.example .env       # fill in your Neon (or Postgres) credentials
npm install
npm run dev                # playground at http://localhost:4000
```

Production mode is what Cloud Run runs (JWT enforced, no playground):

```bash
CUBEJS_DEV_MODE=false NODE_ENV=production CUBEJS_CACHE_AND_QUEUE_DRIVER=memory npm start
```

## Query it

Every BI client, the REST API and the playground speak the same schema. Example — the paywall funnel over the demo year:

```bash
curl http://localhost:4000/cubejs-api/v1/load \
  -H "Authorization: <JWT-signed-with-CUBEJS_API_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "measures": ["paywallFunnel.impressions", "paywallFunnel.clicks",
                   "paywallFunnel.sessionsExposed", "paywallFunnel.newSubscribers",
                   "paywallFunnel.paywallConversionRate"],
      "timeDimensions": [{
        "dimension": "paywallFunnel.eventDate",
        "dateRange": ["2025-04-01", "2026-03-31"],
        "granularity": "month"
      }]
    }
  }'
```

Tokens are JWTs signed with `CUBEJS_API_SECRET`; in dev mode the playground handles them for you.

## Deploy to Cloud Run

Pushes to `main` that touch `cube/**` trigger [`.github/workflows/deploy-cube.yml`](../.github/workflows/deploy-cube.yml): build the Dockerfile, push the image to `gcr.io/chaos87/meridian-cube`, deploy the `meridian-cube` Cloud Run service (us-central1, 1Gi, public endpoint + JWT auth). Mirrors the spotistats `deploy-cubejs.yml` flow.

Required repository secrets:

| Secret | Value |
|---|---|
| `GCP_SA_KEY` | service-account key JSON (same one the spotistats repo uses) |
| `CUBEJS_DB_HOST` / `CUBEJS_DB_NAME` / `CUBEJS_DB_USER` / `CUBEJS_DB_PASS` | Neon warehouse for the dbt layer |
| `CUBEJS_API_SECRET` | long random string — signs the API JWTs |

No Cube Store, no Redis: `CUBEJS_CACHE_AND_QUEUE_DRIVER=memory` and no pre-aggregations.

## Design notes

- **YAML data models, no code** — cubes, measures and dimensions are declarative (`model/*.yml`), mirroring METRICS.md one-to-one. Config lives in `cube.js` (backend 1.7.x reads `cube.js`, not `cube.config.js`, and defaults to a `model/` schema path).
- **Measures compose** — ratios (CTR, conversion rate, pageviews per user) are calculated measures (`{a} / NULLIF({b}, 0)`); cumulative state comes from the as-of cubes described above.
- **Reader state is event-date-aware** — `events.activeSubscribers` classifies each event against the subscription lifecycle (`subscription_date ≤ event date < churn_date`), never against a snapshot flag.
- **No pre-aggregations (v1)** — the demo dataset (~205k events, marts ≤ 42k rows) answers directly on Neon's smallest compute. Add rollups in `cube.js` when query volume demands them — until then Cube Store has nothing to do.- **Auto-deploy** — pushes to `main` touching `cube/**` rebuild and redeploy the Cloud Run service via `.github/workflows/deploy-cube.yml` (image `gcr.io/chaos87/meridian-cube`, us-central1).
