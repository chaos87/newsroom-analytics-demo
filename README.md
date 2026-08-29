# Newsroom Analytics Demo

**A realistic, full-stack web analytics demo for a fictional digital newspaper — *The Meridian Post*.**

Most analytics portfolios point at tired CSV samples. This one takes a different route: a complete, believable digital newspaper with a **GA4-compatible event data model**, synthetic traffic that behaves like real newsroom traffic (direct-heavy attribution, push-notification bursts, breaking-news spikes, weekend dips), and a dashboard that makes it all explorable.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Synthetic data  │     │     Neon         │     │     Cube.js      │
│  generator (…)   │───► │  PostgreSQL      │───► │  semantic layer  │
│  private by      │     │  GA4-style       │     │                  │
│  design          │     │  event model    │     └────────┬─────────┘
└──────────────────┘     └──────────────────┘              │
                                                           ▼
                                                   ┌──────────────────┐
                                                   │  React dashboard │
                                                   │  (Vercel)        │
                                                   └──────────────────┘
```

- **PostgreSQL (Neon)** — GA4-style event model: `pageviews` + `events` fact tables, `users`/`articles` dimensions, pre-aggregated reporting tables
- **Cube.js** — semantic layer so the dashboard never writes raw SQL and metric definitions live in one place
- **React + Vite** — the dashboard

## What's in this repo

- [`db/schema.sql`](db/schema.sql) — complete DDL: 6 tables, keys, FKs, indexes
- [`docs/data-model.md`](docs/data-model.md) — how the model maps to GA4, and why
- `cube/` — Cube.js semantic layer *(in progress)*
- `dashboard/` — React frontend *(in progress)*
- `dbt/` — transformation models *(planned)*

## What's *not* in this repo — on purpose

The synthetic data generator stays private. It's the part that makes this demo *unique* — anyone can write a dashboard over a public dataset, but designing traffic that behaves like a real newsroom (attribution patterns, engagement distributions, breaking-news spikes) is the craft this demo exists to show. The schema, semantic layer, and dashboard — everything you'd need to understand or rebuild the analytics side — are public.

## Why it's shaped like GA4

GA4's event model is the de-facto standard for web analytics. Modeling the demo the same way means the dashboard answers the questions analytics teams actually ask: session handling without a session table, `(direct)/(none)` attribution honesty, engagement time vs. scroll depth, new vs. returning users. [`docs/data-model.md`](docs/data-model.md) walks through every mapping decision.

## Dataset at a glance

| | |
|---|---|
| Time range | 30 days |
| Articles | ~240 across 8 sections |
| Users | ~1,500 |
| Pageviews | ~12,000 |
| Events | ~9,000 |
| Traffic sources | 9 source/medium combinations, direct-heavy like a real newsroom |

## Roadmap

- [x] GA4-compatible schema (PostgreSQL)
- [x] 30 days of realistic synthetic traffic
- [ ] Cube.js semantic layer
- [ ] React dashboard
- [ ] Deploy (Vercel)
- [ ] dbt models

## Tech

PostgreSQL (Neon) · Cube.js · React · dbt

---

Built by [Jonathan Barone](https://www.thedataproductengineer.com/) — analytics engineering, data modeling, and self-serve analytics.