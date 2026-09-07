"use client";

import { Card } from "@/components/Card/Card";
import { formattedNumber, formatPercent, formatDuration, compactNumber } from "@/lib/format";

type KpiFormat = "number" | "compact" | "percent" | "duration" | "decimal";

function renderValue(value: number | null | undefined, format: KpiFormat): string {
  if (value == null || Number.isNaN(value)) return "—";
  switch (format) {
    case "percent":
      return formatPercent(value);
    case "decimal":
      return value.toFixed(2);
    case "duration":
      return formatDuration(value);
    case "compact":
      return compactNumber(value);
    default:
      return formattedNumber(value);
  }
}

export interface KpiCardProps {
  label: string;
  value: number | null | undefined;
  format?: KpiFormat;
  sub?: string;
  accent?: boolean;
}

export function KpiCard({ label, value, format = "number", sub, accent }: KpiCardProps) {
  return (
    <Card className="p-5">
      <p className="text-[10px] uppercase tracking-[0.18em] text-ink-soft">{label}</p>
      <p
        className={
          "mt-2 text-2xl font-semibold tabular-nums md:text-3xl " +
          (accent ? "text-accent" : "text-ink")
        }
      >
        {renderValue(value, format)}
      </p>
      {sub ? <p className="mt-1 text-xs text-ink-soft">{sub}</p> : null}
    </Card>
  );
}