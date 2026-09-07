"use client";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/Select/Select";
import {
  useDateRange,
  PRESETS,
  type DateRange,
  FULL_YEAR,
} from "./date-range-context";
import { DateRangeCalendar } from "./date-range-calendar";

function matchesPreset(range: DateRange, preset: DateRange) {
  return range.from === preset.from && range.to === preset.to;
}

export function PageHeader({
  title,
  subtitle,
  eyebrow,
}: {
  title: string;
  subtitle?: string;
  eyebrow?: string;
}) {
  const { dateRange, setDateRange } = useDateRange();
  const current =
    PRESETS.find((p) => matchesPreset(dateRange, { from: p.from, to: p.to }))?.label ??
    "Custom range";
  return (
    <header className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
      <div>
        {eyebrow ? (
          <p className="text-[10px] uppercase tracking-[0.22em] text-accent">{eyebrow}</p>
        ) : null}
        <h1 className="mt-1 font-serif text-2xl tracking-tight text-ink md:text-3xl">
          {title}
        </h1>
        {subtitle ? <p className="mt-1 text-sm text-ink-soft">{subtitle}</p> : null}
      </div>
      <div className="flex w-full items-start gap-2 md:w-auto md:justify-end">
        <div className="w-full md:w-72">
          <Select
            value={current}
            onValueChange={(label) => {
              const p = PRESETS.find((x) => x.label === label);
              if (p) setDateRange({ from: p.from, to: p.to });
              else setDateRange(FULL_YEAR);
            }}
            aria-label="Date range"
          >
            <SelectTrigger className="w-full">
              <SelectValue>{current}</SelectValue>
            </SelectTrigger>
            <SelectContent>
              {PRESETS.map((p) => (
                <SelectItem key={p.label} value={p.label}>
                  {p.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <DateRangeCalendar value={dateRange} onChange={setDateRange} />
      </div>
    </header>
  );
}