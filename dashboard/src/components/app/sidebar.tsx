"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  RiDashboardLine,
  RiGithubLine,
  RiLineChartLine,
  RiNewspaperLine,
  RiUserHeartLine,
  RiVipCrownLine,
} from "@remixicon/react";
import { cx } from "@/utils/cx";

const NAV = [
  { href: "/overview", label: "Overview", icon: RiDashboardLine },
  { href: "/audience", label: "Audience", icon: RiLineChartLine },
  { href: "/paywall", label: "Paywall", icon: RiVipCrownLine },
  { href: "/content", label: "Content", icon: RiNewspaperLine },
  { href: "/subscriptions", label: "Subscriptions", icon: RiUserHeartLine },
];

export function Sidebar() {
  const pathname = usePathname();
  return (
    <aside className="fixed inset-y-0 left-0 z-40 hidden w-60 flex-col border-r border-newspine bg-white md:flex">
      <Link href="/overview" className="px-6 pt-7 pb-6">
        <p className="font-serif text-xl leading-none tracking-tight text-ink">
          The Meridian Post
        </p>
        <p className="mt-1.5 text-[10px] uppercase tracking-[0.22em] text-ink-soft">
          Analytics Desk
        </p>
      </Link>
      <nav className="flex flex-1 flex-col gap-1 px-3">
        {NAV.map((item) => {
          const active = pathname.startsWith(item.href);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cx(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
                active
                  ? "bg-accent-soft font-medium text-accent"
                  : "text-ink-soft hover:bg-paper hover:text-ink"
              )}
            >
              <Icon size={16} aria-hidden />
              {item.label}
            </Link>
          );
        })}
      </nav>
      <div className="border-t border-newspine px-6 py-4">
        <p className="text-[10px] leading-relaxed text-ink-soft">
          GA4 export → dbt → Cube
          <br />
          semantic layer → Next.js
        </p>
        <a
          href="https://github.com/chaos87/newsroom-analytics-demo"
          target="_blank"
          rel="noopener noreferrer"
          className="mt-2.5 inline-flex items-center gap-1.5 text-[11px] font-medium text-ink-soft transition-colors hover:text-accent"
        >
          <RiGithubLine size={13} aria-hidden />
          View source
          <span aria-hidden="true">↗</span>
        </a>
      </div>
    </aside>
  );
}

/** Mobile top bar with horizontal nav (sidebar hidden below md). */
export function MobileNav() {
  const pathname = usePathname();
  return (
    <div className="sticky top-0 z-40 border-b border-newspine bg-white md:hidden">
      <div className="px-4 pt-4 pb-1">
        <p className="font-serif text-lg leading-none tracking-tight text-ink">
          The Meridian Post
        </p>
        <p className="mt-1 text-[9px] uppercase tracking-[0.22em] text-ink-soft">
          Analytics Desk
        </p>
      </div>
      <nav className="flex gap-1 overflow-x-auto px-2 pb-2">
        {NAV.map((item) => {
          const active = pathname.startsWith(item.href);
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cx(
                "flex shrink-0 items-center gap-1.5 rounded-md px-3 py-1.5 text-xs",
                active
                  ? "bg-accent-soft font-medium text-accent"
                  : "text-ink-soft hover:text-ink"
              )}
            >
              <Icon size={14} aria-hidden />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}