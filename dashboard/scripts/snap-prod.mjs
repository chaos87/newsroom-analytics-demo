import { chromium } from "playwright-core";

const BASE = process.argv[2] ?? "https://meridian-dashboard-liard.vercel.app";
const browser = await chromium.connectOverCDP("http://127.0.0.1:18800");
const ctx = browser.contexts()[0] ?? (await browser.newContext({ viewport: { width: 1440, height: 1000 } }));
const page = await ctx.newPage();
page.setDefaultTimeout(60000);
for (const slug of ["overview", "paywall", "audience", "content", "subscriptions"]) {
  try {
    await page.goto(`${BASE}/${slug}`, { waitUntil: "load" });
    await page.waitForTimeout(15000);
    await page.screenshot({ path: `/home/container/.openclaw/workspace/reports/dash-shots/live-${slug}.png`, fullPage: true });
    console.log(`✅ ${slug}`);
  } catch (e) {
    console.log(`❌ ${slug}: ${e.message}`);
  }
}
await page.close();
await browser.close();
process.exit(0);
