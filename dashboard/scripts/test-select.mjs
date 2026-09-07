import { chromium } from "playwright-core";

const browser = await chromium.connectOverCDP("http://127.0.0.1:18800");
const ctx = browser.contexts()[0] ?? (await browser.newContext());
const page = await ctx.newPage();
page.setDefaultTimeout(45000);

await page.goto("http://localhost:3777/overview", { waitUntil: "load" });
await page.waitForTimeout(12000);
const fullYearSessions = await page.locator("text=42,117").count();
console.log("full-year sessions 42,117 present:", fullYearSessions > 0);

// open the select and pick "Last 90 days"
await page.getByRole("combobox").first().click();
await page.locator('[role="option"], [role="menuitem"]').filter({ hasText: "Last 90 days" }).click();
await page.waitForTimeout(12000);
const q1Sessions = await page.locator("text=10,946").count(); // placeholder; we'll read actual
const bodyText = await page.locator("main").innerText();
const kpiLine = bodyText.split("\n").slice(0, 14).join(" | ");
console.log("KPIs after switching:", kpiLine);
await page.close();
await browser.close();
process.exit(0);
