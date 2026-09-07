"use client";

import { useMemo, useState } from "react";
import { RiArrowLeftSLine, RiArrowRightSLine, RiCalendarLine } from "@remixicon/react";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/Popover/Popover";
import { DATA_MIN, DATA_MAX, type DateRange } from "./date-range-context";

const MIN_MS = Date.UTC(2025, 3, 1); // 2025-04-01
const MAX_MS = Date.UTC(2026, 2, 31); // 2026-03-31
const DAY_MS = 86_400_000;

const WEEKDAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];
const MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const pad2 = (n: number) => String(n).padStart(2, "0");
const toMs = (key: string) => {
  const [y, m, d] = key.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
};
const toKey = (ms: number) => {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
};
const shortDate = (key: string) => {
  const d = new Date(toMs(key));
  return `${MONTH_SHORT[d.getUTCMonth()]} ${d.getUTCDate()}`;
};

function cxParts(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export function DateRangeCalendar({
  value,
  onChange,
}: {
  value: DateRange;
  onChange: (r: DateRange) => void;
}) {
  const [open, setOpen] = useState(false);
  const [view, setView] = useState({ y: 2026, m: 2 }); // Mar 2026
  const [from, setFrom] = useState<string | null>(null);
  const [to, setTo] = useState<string | null>(null);

  const openCalendar = () => {
    setFrom(value.from);
    setTo(value.to);
    const d = new Date(toMs(value.from));
    setView({ y: d.getUTCFullYear(), m: d.getUTCMonth() });
    setOpen(true);
  };

  /** First click sets the start, second click completes + applies the range. */
  const pick = (key: string) => {
    if (from === null || to !== null) {
      setFrom(key);
      setTo(null);
      return;
    }
    let a = from;
    let b = key;
    if (toMs(b) < toMs(a)) [a, b] = [b, a];
    setFrom(a);
    setTo(b);
    onChange({ from: a, to: b });
    setOpen(false);
  };

  const { leadDays, daysInMonth } = useMemo(() => {
    const first = Date.UTC(view.y, view.m, 1);
    const leadDays = (new Date(first).getUTCDay() + 6) % 7; // Monday-start offset
    const daysInMonth = new Date(Date.UTC(view.y, view.m + 1, 0)).getUTCDate();
    return { leadDays, daysInMonth };
  }, [view]);

  const canPrev = Date.UTC(view.y, view.m, 1) > MIN_MS;
  const canNext = Date.UTC(view.y, view.m, 1) < Date.UTC(2026, 2, 1);

  return (
    <Popover
      open={open}
      onOpenChange={(o) => {
        if (o) openCalendar();
        else setOpen(false);
      }}
    >
      <PopoverTrigger asChild>
        <button
          type="button"
          aria-label="Pick custom date range"
          onClick={openCalendar}
          className="flex shrink-0 items-center justify-center gap-2 rounded-md border border-gray-200 bg-white px-3 py-2 shadow-xs outline-hidden transition hover:bg-accent-soft sm:justify-start"
        >
          <RiCalendarLine className="size-4 shrink-0 text-ink-soft" aria-hidden="true" />
          <span className="hidden whitespace-nowrap text-sm text-ink sm:inline">
            {shortDate(value.from)} – {shortDate(value.to)}
          </span>
        </button>
      </PopoverTrigger>
      <PopoverContent align="end" sideOffset={8} className="w-auto p-3">
        <div className="w-72" role="dialog" aria-label="Custom date range">
          {/* header */}
          <div className="flex items-center justify-between">
            <button
              type="button"
              aria-label="Previous month"
              disabled={!canPrev}
              onClick={() => setView((v) => (v.m === 0 ? { y: v.y - 1, m: 11 } : { ...v, m: v.m - 1 }))}
              className="flex size-7 items-center justify-center rounded-md text-ink-soft transition hover:bg-accent-soft disabled:cursor-not-allowed disabled:opacity-30"
            >
              <RiArrowLeftSLine className="size-4" aria-hidden="true" />
            </button>
            <p className="text-sm font-medium text-ink">
              {MONTH_NAMES[view.m]} {view.y}
            </p>
            <button
              type="button"
              aria-label="Next month"
              disabled={!canNext}
              onClick={() => setView((v) => (v.m === 11 ? { y: v.y + 1, m: 0 } : { ...v, m: v.m + 1 }))}
              className="flex size-7 items-center justify-center rounded-md text-ink-soft transition hover:bg-accent-soft disabled:cursor-not-allowed disabled:opacity-30"
            >
              <RiArrowRightSLine className="size-4" aria-hidden="true" />
            </button>
          </div>

          {/* weekday header */}
          <div className="mt-2 grid grid-cols-7">
            {WEEKDAYS.map((d) => (
              <span key={d} className="flex h-6 items-center justify-center text-[11px] font-medium uppercase tracking-wide text-ink-soft">
                {d}
              </span>
            ))}
          </div>

          {/* day grid */}
          <div className="grid grid-cols-7 gap-y-0.5">
            {Array.from({ length: leadDays }).map((_, i) => (
              <span key={`lead-${i}`} />
            ))}
            {Array.from({ length: daysInMonth }).map((_, i) => {
              const day = i + 1;
              const ms = Date.UTC(view.y, view.m, day);
              const key = toKey(ms);
              const disabled = ms < MIN_MS || ms > MAX_MS;
              const isEnd = key === from || key === to;
              const inRange = from !== null && to !== null && ms > toMs(from) && ms < toMs(to);
              return (
                <button
                  key={key}
                  type="button"
                  disabled={disabled}
                  onClick={() => pick(key)}
                  className={cxParts(
                    "flex h-8 w-8 items-center justify-center rounded-md text-sm tabular-nums transition outline-hidden",
                    disabled
                      ? "cursor-not-allowed text-ink-soft opacity-30"
                      : isEnd
                        ? "bg-accent text-white hover:bg-accent"
                        : inRange
                          ? "bg-accent-soft text-ink"
                          : "text-ink hover:bg-accent-soft",
                  )}
                >
                  {day}
                </button>
              );
            })}
          </div>

          <p className="mt-2 text-center text-[11px] text-ink-soft">
            {from !== null && to !== null
              ? "Pick a day to start a new range"
              : from !== null
                ? "Now pick the end date"
                : "Pick the start date"}
          </p>
        </div>
      </PopoverContent>
    </Popover>
  );
}