#!/usr/bin/env node
/**
 * Dashboard validation: runs every Cube query the pages make and checks
 * the numbers against the pipeline control figures from METRICS.md.
 * Usage: node scripts/validate-dashboard.mjs
 */
import { readFileSync } from "node:fs";

const env = readFileSync(new URL("../../cube/.env", import.meta.url), "utf8");
const SECRET = env.match(/^CUBEJS_API_SECRET=(.+)$/m)[1].trim();
const API = "https://meridian-cube-327801019934.us-central1.run.app/cubejs-api/v1";

const RANGE = ["2025-04-01", "2026-03-31"];

const header = new Uint8Array(12);
const b64url = (buf) => Buffer.from(buf).toString("base64url");
const h = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
const p = b64url(JSON.stringify({ exp: Math.floor(Date.now() / 1000) + 3600 }));
import { createHmac } from "node:crypto";
const sig = createHmac("sha256", SECRET).update(`${h}.${p}`).digest("base64url");
const TOKEN = `${h}.${p}.${sig}`;

async function load(query, maxWaits = 40) {
  let requestId;
  for (let attempt = 0; attempt <= maxWaits; attempt++) {
    const res = await fetch(`${API}/load`, {
      method: "POST",
      headers: { Authorization: `Bearer ${TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify(requestId ? { requestId } : { query }),
    });
    const json = await res.json();
    if (json.error === "Continue wait") {
      requestId = json.requestId;
      await new Promise((r) => setTimeout(r, 1500));
      continue;
    }
    if (json.error) throw new Error(`Query failed: ${JSON.stringify(query)} → ${json.error}`);
    const data = json.data;
    if (!data || !data.length) return {};
    const out = {};
    for (const [k, v] of Object.entries(data[0])) out[k] = Number(v);
    return out;
  }
  throw new Error(`Query timed out: ${JSON.stringify(query)}`);
}

let failures = 0;
function check(name, actual, expected) {
  const ok = actual === expected;
  if (!ok) failures++;
  console.log(`${ok ? "✅" : "❌"} ${name}: ${actual}${ok ? "" : ` (expected ${expected})`}`);
}

// ---- Overview / Audience ----
const sessions = await load({
  measures: ["sessions.sessions", "sessions.activeUsers"],
  timeDimensions: [{ dimension: "sessions.eventDate", dateRange: RANGE }],
});
check("Sessions", sessions["sessions.sessions"], 42117);
check("Active users", sessions["sessions.activeUsers"], 4119);

const pages = await load({
  measures: ["pages.pageviews"],
  timeDimensions: [{ dimension: "pages.eventDate", dateRange: RANGE }],
});
check("Pageviews (pages cube)", pages["pages.pageviews"], 70373);

const events = await load({
  measures: ["events.eventsCount"],
  timeDimensions: [{ dimension: "events.eventDate", dateRange: RANGE }],
});
check("Events", events["events.eventsCount"], 204388);

// ---- Paywall ----
const paywall = await load({
  measures: ["paywall.impressions", "paywall.clicks", "paywall.ctr"],
  timeDimensions: [{ dimension: "paywall.eventDate", dateRange: RANGE }],
});
check("Paywall impressions", paywall["paywall.impressions"], 31977);
check("Paywall clicks", paywall["paywall.clicks"], 1614);
check("Paywall CTR (basis points)", Math.round(paywall["paywall.ctr"] * 10000), 505);

const funnel = await load({
  measures: [
    "paywallFunnel.sessionsExposed",
    "paywallFunnel.paywallConversionRate",
    "paywallFunnel.newSubscribers",
  ],
  timeDimensions: [{ dimension: "paywallFunnel.eventDate", dateRange: RANGE }],
});
check("Exposed sessions", funnel["paywallFunnel.sessionsExposed"], 25615);
check("Session conversion", Math.round(funnel["paywallFunnel.paywallConversionRate"] * 10000), 100);
check("Same-day subs", funnel["paywallFunnel.newSubscribers"], 256);

// ---- Subscriptions / CRM ----
const crm = await load({
  measures: ["crm.newSubscribers", "crm.newChurns", "crm.newRegisteredUsers"],
  timeDimensions: [{ dimension: "crm.subscriptionDate", dateRange: RANGE }],
});
check("New subscribers", crm["crm.newSubscribers"], 256);

const churn = await load({
  measures: ["crm.newChurns"],
  timeDimensions: [{ dimension: "crm.churnDate", dateRange: RANGE }],
});
check("New churns", churn["crm.newChurns"], 52);

const crmTotals = await load({
  measures: [
    "crmTotals.numberOfSubscribers",
    "crmTotals.numberOfRegisteredUsers",
    "crmTotals.cumulativeSubscribers",
    "crmTotals.cumulativeChurns",
  ],
  timeDimensions: [{ dimension: "crmTotals.asOfDate", dateRange: ["2026-03-31", "2026-03-31"] }],
});
check("Active subscribers @2026-03-31", crmTotals["crmTotals.numberOfSubscribers"], 204);
check("Registered users @2026-03-31", crmTotals["crmTotals.numberOfRegisteredUsers"], 350);
check("Cumulative subscribers", crmTotals["crmTotals.cumulativeSubscribers"], 256);
check("Cumulative churns", crmTotals["crmTotals.cumulativeChurns"], 52);

// ---- Content ----
const content = await load({
  measures: ["content.articlesPublished"],
  timeDimensions: [{ dimension: "content.publicationDate", dateRange: RANGE }],
});
console.log(`ℹ️  Articles published in demo year: ${content["content.articlesPublished"]}`);

const inv = await load({
  measures: ["contentTotals.numberOfArticles"],
  timeDimensions: [{ dimension: "contentTotals.asOfDate", dateRange: ["2026-03-31", "2026-03-31"] }],
});
check("Total articles @2026-03-31", inv["contentTotals.numberOfArticles"], 1000);

const articles = await load({
  measures: ["articles.articlePageviews"],
  timeDimensions: [{ dimension: "articles.eventDate", dateRange: RANGE }],
});
check("Article pageviews", articles["articles.articlePageviews"], 70373);

// ---- Slices used by pages (no exact control numbers, just sanity) ----
const byType = await load({
  measures: ["paywall.impressions", "paywall.clicks", "paywall.ctr"],
  dimensions: ["paywall.paywallType"],
  timeDimensions: [{ dimension: "paywall.eventDate", dateRange: RANGE }],
});
console.log("ℹ️  Paywall by type query ran OK (rows not asserted)");

const channels = await load({
  measures: ["traffic.sessions"],
  dimensions: ["traffic.channelGrouping"],
  timeDimensions: [{ dimension: "traffic.eventDate", dateRange: RANGE }],
});
console.log("ℹ️  Channel grouping query ran OK");

const trendMonth = await load({
  measures: ["sessions.sessions", "sessions.pageviews"],
  timeDimensions: [{ dimension: "sessions.eventDate", dateRange: RANGE, granularity: "month" }],
});
console.log("ℹ️  Monthly trend query ran OK");

const subsByTier = await load({
  measures: ["subscriptions.newSubscribers"],
  dimensions: ["subscriptions.tier"],
  timeDimensions: [{ dimension: "subscriptions.subscriptionDate", dateRange: RANGE }],
});
console.log("ℹ️  Tier split query ran OK");

console.log(failures === 0 ? "\n🎉 ALL CONTROL CHECKS PASSED" : `\n💥 ${failures} check(s) failed`);
process.exit(failures === 0 ? 0 : 1);