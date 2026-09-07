# Meridian Post Dashboard

The analytics consumer of the [newsroom-analytics-demo](../README.md) pipeline: a Next.js (App Router) dashboard that queries the **Cube.js semantic layer** on Cloud Run — five pages, one date-range control, every number reconciled to [METRICS.md](../METRICS.md).

## Stack

- **Next.js 16** (App Router, TypeScript, Tailwind v4)
- **Tremor Raw** copy-paste components — [tremorlabs/tremor](https://github.com/tremorlabs/tremor) (Radix UI + Tailwind, charts on Recharts, Apache 2.0)
- **@cubejs-client/react** for queries; `src/lib/cube-data.ts` turns result sets into Tremor chart shapes (case-insensitive member resolution)
- **JWT pattern:** a Next.js route handler (`src/app/api/cube-token/route.ts`) mints a short-lived Cube JWT server-side — `CUBEJS_API_SECRET` never reaches the browser
- Design: newsprint/editorial aesthetic — see `DESIGN.md` and `PRODUCT.md`

## Pages

| Route | The question it answers |
|---|---|
| `/overview` | How is the paper doing? |
| `/audience` | Where do readers come from? |
| `/paywall` | Is the paywall working, and which wall converts? |
| `/content` | What do people actually read? |
| `/subscriptions` | Are we growing the paying base faster than it churns? |

## Run locally

```bash
npm install
cp .env.example .env.local    # set NEXT_PUBLIC_CUBEJS_API_URL + CUBEJS_API_SECRET
npm run dev
```

## Validate

`node scripts/validate-dashboard.mjs` runs every page's Cube queries and asserts the METRICS.md control figures (42,117 sessions · 70,373 pageviews · 5.05% paywall CTR · 1.00% session conversion · 256 new subs · 52 churns · 204 active).

`node scripts/snap.mjs` renders all five pages through a local Chromium (CDP on :18800) and dumps DOM + full-page screenshots for offline review.
