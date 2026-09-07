import { chromium } from "playwright-core";
const browser = await chromium.connectOverCDP("http://127.0.0.1:18800");
const ctx = browser.contexts()[0] ?? (await browser.newContext({ viewport: { width: 1440, height: 900 } }));
const page = await ctx.newPage();
for (const slug of ["audience", "paywall", "content", "subscriptions"]) {
  await page.goto(`http://localhost:3777/${slug}`, { waitUntil: "load" });
  await page.waitForTimeout(15000);
  const r = await page.evaluate(() => {
    const out = [];
    document.querySelectorAll("main .rounded-lg").forEach((card) => {
      const title = card.querySelector("p")?.textContent?.trim() ?? "?";
      const svg = card.querySelector("svg");
      if (!svg) return;
      const rects = svg.querySelectorAll("rect").length;
      const rectsFilled = Array.from(svg.querySelectorAll("rect")).filter((r) => r.getAttribute("width") && Number(r.getAttribute("width")) > 1 && r.getAttribute("height") && Number(r.getAttribute("height")) > 1).length;
      out.push({ title: title.slice(0, 26), rects, rectsFilled });
    });
    return out;
  });
  console.log(`=== ${slug} ===`);
  for (const e of r) console.log(`  ${e.title} | rects:${e.rects} filled:${e.rectsFilled}`);
}
await page.close();
await browser.close();
process.exit(0);
