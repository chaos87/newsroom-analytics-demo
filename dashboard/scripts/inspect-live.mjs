import { chromium } from "playwright-core";

const browser = await chromium.connectOverCDP("http://127.0.0.1:18800");
const ctx = browser.contexts()[0] ?? (await browser.newContext({ viewport: { width: 1440, height: 900 } }));
const page = await ctx.newPage();
await page.goto("http://localhost:3777/overview", { waitUntil: "load" });
await page.waitForTimeout(15000);

const report = await page.evaluate(() => {
  const out = [];
  // every chart card
  document.querySelectorAll("main .rounded-lg").forEach((card) => {
    const title = card.querySelector("p")?.textContent?.trim() ?? "?";
    const svg = card.querySelector("svg");
    const r = card.getBoundingClientRect();
    const entry = {
      title,
      card: { w: Math.round(r.width), h: Math.round(r.height) },
    };
    if (svg) {
      const s = svg.getBoundingClientRect();
      entry.svg = { w: Math.round(s.width), h: Math.round(s.height) };
      const paths = svg.querySelectorAll("path");
      entry.paths = paths.length;
      // recharts area/curve paths have "d" starting with M and real coords
      entry.nonEmptyPaths = Array.from(paths).filter((p) => (p.getAttribute("d") || "").length > 40).length;
      entry.sectors = svg.querySelectorAll(".recharts-pie-sector, .recharts-sector").length;
      entry.hasAreaFill = Array.from(paths).some((p) => (p.getAttribute("fill") || "none") !== "none" && (p.getAttribute("d") || "").includes("L"));
      entry.leftVsCenter = Math.round((s.x - r.x + s.width / 2) - r.width / 2);
    } else entry.svg = null;
    out.push(entry);
  });
  return out;
});
console.log(JSON.stringify(report, null, 1));
await page.close();
await browser.close();
process.exit(0);
