import cube from "@cubejs-client/core";
import { readFileSync } from "node:fs";
import { createHmac } from "node:crypto";

const env = readFileSync(
  "/home/container/.openclaw/workspace/newsroom-analytics-demo/cube/.env",
  "utf8"
);
const SECRET = env
  .split("\n")
  .find((l) => l.startsWith("CUBEJS_API_SECRET="))
  .split("=")
  .slice(1)
  .join("=")
  .trim();
const b64u = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
const h = b64u({ alg: "HS256", typ: "JWT" });
const p = b64u({ exp: Math.floor(Date.now() / 1000) + 3600 });
const TOKEN = `${h}.${p}.${createHmac("sha256", SECRET).update(`${h}.${p}`).digest("base64url")}`;

const api = cube(TOKEN, {
  apiUrl: "https://meridian-cube-327801019934.us-central1.run.app/cubejs-api/v1",
});

const rs = await api.load({
  measures: ["sessions.sessions", "sessions.pageviews"],
  timeDimensions: [
    {
      dimension: "sessions.eventDate",
      dateRange: ["2025-04-01", "2026-03-31"],
      granularity: "month",
    },
  ],
});

const cp = rs.chartPivot();
console.log(
  "first 3 chartPivot rows:",
  JSON.stringify(cp.slice(0, 3), null, 1)
);
console.log(
  "seriesNames:",
  JSON.stringify(
    rs.seriesNames().map((s) => ({ key: s.key, title: s.title })),
    null,
    1
  )
);