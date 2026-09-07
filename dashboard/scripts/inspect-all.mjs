import { chromium } from "playwright-core";
const browser = await chromium.connectOverCDP("http://127.0.0.1:18800");
const ctx = browser.contexts()[0] ?? (await browser.newContext({ viewport: { width: 1440, height: 900 } }));
const page = await ctx.newPage();
for (const slug of ["overview", "audience", "paywall", "content", "subscriptions"]) {
  await page.goto(`https://meridian-dashboard-liard.vercel.app/${slug}`, { waitUntil: "load" });
  await page.waitForTimeout(15000);
  const r = await page.evaluate(() => {
    const out = [];
    document.querySelectorAll("main .rounded-lg").forEach((card) => {
      const title = card.querySelector("p")?.textContent?.trim() ?? "?";
      const svg = card.querySelector("svg");
      if (!svg) return;
      const s = svg.getBoundingClientRect();
      const cr = card.getBoundingClientRect();
      out.push({
        title: title.slice(0, 26),
        paths: svg.querySelectorAll("path").length,
        offCenter: Math.round(s.x - cr.x + s.width / 2 - cr.width / 2),
        texts: Array.from(svg.querySelectorAll("text")).slice(0, 5).map((t) => t.textContent).filter(Boolean),
      });
    });
    return out;
  });
  console.log(`\n=== ${slug} ===`);
  for (const e of r) console.log(`  ${e.title} | paths:${e.paths} | offC:${e.offCenter} | ticks:${e.texts.join(", ").slice(0, 70)}`);
}
await page.close();
await browser.close();
process.exit(0);
