import { chromium } from "playwright-core";
import { writeFileSync } from "node:fs";

const browser = await chromium.connectOverCDP("http://127.0.0.1:18800");
const ctx = browser.contexts()[0] ?? (await browser.newContext());
const page = await ctx.newPage();
page.setDefaultTimeout(60000);

for (const slug of ["overview", "audience", "paywall", "content", "subscriptions"]) {
  try {
    await page.goto(`http://localhost:3777/${slug}`, { waitUntil: "load" });
    await page.waitForTimeout(18000); // real time for Cube queries (incl. Continue-wait resumes)
    const html = await page.content();
    writeFileSync(`/tmp/dom-${slug}.html`, html);
    await page.screenshot({ path: `/tmp/shot-${slug}.png`, fullPage: true });
    console.log(`✅ ${slug} (${html.length} bytes)`);
  } catch (e) {
    console.log(`❌ ${slug}: ${e.message}`);
  }
}
await page.close();
await browser.close();
process.exit(0);
