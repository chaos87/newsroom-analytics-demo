"use client";

import { createContext, useContext, useMemo, useState, type ReactNode } from "react";

export interface DateRange {
  from: string; // YYYY-MM-DD
  to: string;   // YYYY-MM-DD
}

export const FULL_YEAR: DateRange = { from: "2025-04-01", to: "2026-03-31" };

const PRESETS: { label: string; from: string; to: string }[] = [
  { label: "Full year (Apr '25 – Mar '26)", from: "2025-04-01", to: "2026-03-31" },
  { label: "Last 90 days", from: "2026-01-01", to: "2026-03-31" },
  { label: "Last 30 days", from: "2026-03-01", to: "2026-03-31" },
  { label: "H1 (Apr – Sep '25)", from: "2025-04-01", to: "2025-09-30" },
  { label: "H2 (Oct '25 – Mar '26)", from: "2025-10-01", to: "2026-03-31" },
];

export { PRESETS };

interface DateRangeContextValue {
  dateRange: DateRange;
  setDateRange: (r: DateRange) => void;
}

const DateRangeContext = createContext<DateRangeContextValue>({
  dateRange: FULL_YEAR,
  setDateRange: () => {},
});

export function DateRangeProvider({ children }: { children: ReactNode }) {
  const [dateRange, setDateRange] = useState<DateRange>(FULL_YEAR);
  const value = useMemo(() => ({ dateRange, setDateRange }), [dateRange]);
  return <DateRangeContext.Provider value={value}>{children}</DateRangeContext.Provider>;
}

export function useDateRange() {
  return useContext(DateRangeContext);
}

/** Choose a Cube time grain appropriate for the selected range. */
export function grainForRange(range: DateRange): "day" | "week" | "month" {
  const days =
    (new Date(range.to).getTime() - new Date(range.from).getTime()) / 86400000;
  if (days <= 31) return "day";
  if (days <= 120) return "week";
  return "month";
}