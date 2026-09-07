import { compactNumber, formattedNumber } from "@/utils/number-format";

export { compactNumber, formattedNumber };

export function formatPercent(value: number | null | undefined, digits = 2): string {
  if (value == null || Number.isNaN(value)) return "—";
  return `${(value * 100).toFixed(digits)}%`;
}

/** Seconds → "2m 14s" / "38s" */
export function formatDuration(seconds: number | null | undefined): string {
  if (seconds == null || Number.isNaN(seconds)) return "—";
  if (seconds < 60) return `${Math.round(seconds)}s`;
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds % 60);
  return `${m}m ${s}s`;
}

export function formatDelta(current: number, previous: number): string {
  if (!previous) return "—";
  const d = (current - previous) / previous;
  return `${d >= 0 ? "+" : ""}${(d * 100).toFixed(1)}%`;
}