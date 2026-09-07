# DESIGN.md — Visual System

*The dashboard reads like the paper it measures: editorial, newsprint, ink-on-paper. Data is the hero; chrome stays quiet.*

## Brand concept: "Newsprint"
- Warm paper background, white cards, warm ink text, one editorial red accent.
- Serif masthead + section titles (newspaper voice); sans for all data and UI.
- Charts use Tremor's neutral palette; red is reserved for subscriptions/monetization and emphasis.

## Tokens (Tailwind v4 theme)
| Token | Value | Use |
|---|---|---|
| `paper` | `#F5F1E8` | App background |
| `ink` | `#1A1712` | Primary text |
| `ink-soft` | `#6B6255` | Secondary text |
| `accent` | `#B4232A` | Editorial red — brand emphasis, subscription series, active nav |
| `accent-soft` | `#F6E4E1` | Red tint backgrounds |

## Typography
- **Masthead:** Playfair Display (serif), tracking-tight — "The Meridian Post" wordmark + page titles.
- **UI + data:** Inter. Numbers use `tabular-nums`. KPI values `text-3xl font-semibold`; labels `text-xs uppercase tracking-widest text-ink-soft`.
- Never serif below 16px (legibility).

## Layout
- Fixed left sidebar (64px rail on mobile → 240px on lg): wordmark, 5 nav items with Remix icons, footer note "Powered by dbt → Cube".
- Content: max-w-7xl, 24px gutts. Page = PageHeader (serif title + date-range control) → KPI row (cards) → chart grid (2-col on lg, 1-col mobile).
- Cards: Tremor Card, `p-5`, white on paper. Chart titles: `text-sm font-medium text-ink`, subtitle `text-xs text-ink-soft`.

## Chart rules
- One chart = one question, titled as a question or statement ("Where readers come from").
- Max 6 categories per bar/donut — collapse to "Other".
- Trend default: monthly grain for the full year; weekly below 120 days; daily below 32.
- Money metrics (subscribers) = red series. Traffic = neutral/gray-blue. Never rainbow.
- Always show units in axis/labels; CTR/rates to 2 decimals ("5.05%"), durations humanized ("2m 14s").

## States
- Loading: card keeps layout with skeleton pulse (no spinner takeover).
- Empty (no rows in range): quiet note "No data in this range."
- Error: Callout in ink-soft, no red unless data integrity is wrong.

## Dark mode
Not in v1 — newsprint is the identity. (Tremor components ship dark classes for free; enable later if asked.)