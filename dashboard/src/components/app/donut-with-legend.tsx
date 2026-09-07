"use client";

import { useMemo } from "react";
import { DonutChart } from "@/components/DonutChart/DonutChart";
import {
  type AvailableChartColorsKeys,
  constructCategoryColors,
  getColorClassName,
} from "@/utils/chartColors";

/**
 * Donut + label-only legend, centered in the card (horizontal + vertical).
 * Legend colors mirror DonutChart's own assignment (categories in
 * order of first appearance mapped onto the colors array in order).
 */
export function DonutWithLegend({
  data,
  category = "name",
  value = "value",
  colors,
  className,
}: {
  data: Record<string, unknown>[];
  category?: string;
  value?: string;
  colors: AvailableChartColorsKeys[];
  className?: string;
}) {
  const rows = useMemo(() => {
    const categories = Array.from(new Set(data.map((d) => String(d[category]))));
    const colorMap = constructCategoryColors(categories, colors);
    return categories.map((name) => ({
      name,
      color: colorMap.get(name) ?? colors[0],
    }));
  }, [data, category, colors]);

  return (
    <div
      className={
        "flex h-full flex-col items-center justify-center gap-4 sm:flex-row sm:gap-6 " +
        (className ?? "")
      }
    >
      <DonutChart data={data} category={category} value={value} colors={colors} />
      <ul className="w-28 shrink-0 space-y-1.5 sm:w-32">
        {rows.map((row) => (
          <li key={row.name} className="flex items-center gap-2 text-sm">
            <span
              aria-hidden="true"
              className={`size-2 shrink-0 rounded-full ${getColorClassName(row.color, "bg")}`}
            />
            <span className="truncate text-ink-soft">{row.name}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}