import { chromium } from "playwright-core";
const browser = await chromium.connectOverCDP("http://127.0.0.1:18800");
const ctx = browser.contexts()[0] ?? (await browser.newContext({ viewport: { width: 1440, height: 900 } }));
const page = await ctx.newPage();
await page.goto("http://localhost:3777/overview", { waitUntil: "load" });
await page.waitForTimeout(15000);
const result = await page.evaluate(() => {
  // find the Audience trend card, then the h-80 chart div
  const cards = Array.from(document.querySelectorAll("main .rounded-lg"));
  const trendCard = cards.find((c) => c.textContent.includes("Audience trend"));
  if (!trendCard) return { error: "trend card not found" };
  const chartDiv = trendCard.querySelector(".h-80");
  if (!chartDiv) return { error: "h-80 chart div not found" };
  // walk to React fiber
  const key = Object.keys(chartDiv).find((k) => k.startsWith("__reactFiber$"));
  if (!key) return { error: "no fiber" };
  let fiber = chartDiv[key];
  // go up/down looking for AreaChart component with data prop
  let found = null;
  const visited = new Set();
  function walk(f, depth) {
    if (!f || depth > 30 || visited.has(f)) return;
    visited.add(f);
    const props = f.memoizedProps;
    if (props && props.data && props.index === "date" && Array.isArray(props.data)) {
      found = { dataLen: props.data.length, sample: props.data.slice(0, 2), categories: props.categories, colors: props.colors, index: props.index };
      return;
    }
    walk(f.child, depth + 1); walk(f.sibling, depth + 1); walk(f.return, depth + 1);
    if (found) return;
  }
  walk(fiber, 0);
  // also count svg internals
  const svg = trendCard.querySelector("svg");
  const svgStats = svg ? {
    paths: svg.querySelectorAll("path").length,
    lines: svg.querySelectorAll("line").length,
    texts: svg.querySelectorAll("text").length,
    textsSample: Array.from(svg.querySelectorAll("text")).slice(0, 4).map(t => t.textContent),
  } : null;
  return { chartProps: found, svgStats };
});
console.log(JSON.stringify(result, null, 1));
await page.close();
await browser.close();
process.exit(0);
