# PRODUCT.md — The Meridian Post Analytics Dashboard

## What
A newsroom analytics dashboard for **The Meridian Post**, a fictional digital newspaper, built on a GA4-native data pipeline (GA4 export schema on Neon → dbt → Cube semantic layer → this Next.js app).

## Who
- **Primary reader:** The newsroom's editor-in-chief and growth lead — they open it to answer "how are we doing?" in under 30 seconds.
- **Portfolio visitor:** Data/analytics hiring managers and consulting prospects evaluating Jonathan Barone's data-product work. The dashboard *is* the demo.

## Why
- Prove the full modern data stack end-to-end with realistic data: semantic layer (Cube) as the single metric source, dashboard as its consumer.
- Every number on screen must be traceable: METRICS.md definition → dbt model → Cube measure → chart.

## Jobs to be done
1. "Are traffic and subscriptions trending up or down, and why?" → Overview page
2. "Where does our audience come from?" → Audience page
3. "Is the paywall working? Which wall converts?" → Paywall page
4. "What content performs, and what do people actually read?" → Content page
5. "Are we growing the subscriber base faster than we churn it?" → Subscriptions page

## Non-goals
- Real-time streaming (daily batch data, demo year Apr 2025 → Mar 2026)
- Self-serve exploration (curated pages only; drill-down via Cube is possible later)
- Auth on the dashboard itself (public, synthetic data; Cube API stays JWT-gated)

## Success criteria
- Every headline number matches the pipeline control figures (42,117 sessions, 70,373 pageviews, 31,977 impressions, CTR 5.05%, conv 1.00%, 256 new subs, 52 churns, 204 active).
- A first-time visitor understands the business story in one minute.