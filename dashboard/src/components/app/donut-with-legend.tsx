"use client";

import { useMemo } from "react";
import { DonutChart } from "@/components/DonutChart/DonutChart";
import {
  type AvailableChartColorsKeys,
  constructCategoryColors,
  getColorClassName,
} from "@/utils/chartColors";

/**
 * Donut + legend, centered in the card (horizontal + vertical).
 * Legend colors mirror DonutChart's own assignment (categories in
 * order of first appearance mapped onto the colors array in order).
 */
export function DonutWithLegend({
  data,
  category = "name",
  value = "value",
  colors,
  valueFormatter,
  className,
}: {
  data: Record<string, unknown>[];
  category?: string;
  value?: string;
  colors: AvailableChartColorsKeys[];
  valueFormatter?: (v: number) => string;
  className?: string;
}) {
  const fmt = valueFormatter ?? ((v: number) => v.toLocaleString());

  const { rows, total } = useMemo(() => {
    const categories = Array.from(new Set(data.map((d) => String(d[category]))));
    const colorMap = constructCategoryColors(categories, colors);
    const total = data.reduce((sum, d) => sum + (Number(d[value]) || 0), 0);
    const rows = data.map((d) => {
      const name = String(d[category]);
      const val = Number(d[value]) || 0;
      return {
        name,
        val,
        color: colorMap.get(name) ?? colors[0],
        pct: total > 0 ? Math.round((val / total) * 100) : null,
      };
    });
    return { rows, total };
  }, [data, category, value, colors]);

  return (
    <div
      className={
        "flex h-full flex-col items-center justify-center gap-4 sm:flex-row sm:gap-6 " +
        (className ?? "")
      }
    >
      <DonutChart data={data} category={category} value={value} colors={colors} />
      <ul className="w-40 shrink-0 space-y-1.5 sm:w-44">
        {rows.map((row) => (
          <li key={row.name} className="flex items-center gap-2 text-sm">
            <span
              aria-hidden="true"
              className={`size-2 shrink-0 rounded-full ${getColorClassName(row.color, "bg")}`}
            />
            <span className="truncate text-ink-soft">{row.name}</span>
            <span className="ml-auto pl-2 text-right font-medium tabular-nums text-ink">
              {fmt(row.val)}
              {row.pct !== null ? (
                <span className="font-normal text-ink-soft"> · {row.pct}%</span>
              ) : null}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}