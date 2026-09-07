"use client";

/**
 * Shared helpers for turning Cube result sets into Tremor-friendly shapes.
 * Cube returns members keyed as-requested (e.g. "sessions.sessions") while the
 * JS client sometimes surfaces resolved names ("Sessions.sessions") — every
 * lookup below is therefore case-insensitive.
 */

export type RS = {
  chartPivot: () => Record<string, any>[];
  tablePivot: () => Record<string, any>[];
  rawData: () => Record<string, any>[];
};

/** Resolve a member key case-insensitively against a result row. */
export function actualKey(row: Record<string, any>, key: string): string | null {
  if (key in row) return key;
  const lower = key.toLowerCase();
  const found = Object.keys(row).find((k) => k.toLowerCase() === lower);
  return found ?? null;
}

/** Safe cell read with case-insensitive member resolution. */
export function cell(row: Record<string, any>, key: string): any {
  const k = actualKey(row, key);
  return k == null ? undefined : row[k];
}

export function num(resultSet: RS | null | undefined, key: string): number | null {
  if (!resultSet) return null;
  const row = resultSet.rawData()[0];
  if (!row) return null;
  const v = cell(row, key);
  if (v == null) return null;
  const n = Number(v);
  return Number.isNaN(n) ? null : n;
}

/**
 * Time-series → chart data with friendly category names.
 * series: { "sessions.sessions": "Sessions" }  (cubeKey → display name)
 */
export function trend(
  resultSet: RS | null | undefined,
  series: Record<string, string>
): { data: Record<string, any>[]; categories: string[] } {
  if (!resultSet) return { data: [], categories: [] };
  const categories = Object.values(series);
  const data = resultSet.chartPivot().map((row) => {
    const out: Record<string, any> = { date: row.x };
    for (const [key, name] of Object.entries(series)) {
      out[name] = Number(cell(row, key) ?? 0);
    }
    return out;
  });
  return { data, categories };
}

/** GroupBy breakdown → [{ name, value }] sorted desc. */
export function breakdown(
  resultSet: RS | null | undefined,
  nameKey: string,
  valueKey: string,
  limit?: number
): { name: string; value: number }[] {
  if (!resultSet) return [];
  const rows = resultSet
    .tablePivot()
    .map((row) => ({
      name: String(cell(row, nameKey) ?? "—"),
      value: Number(cell(row, valueKey) ?? 0),
    }))
    .filter((r) => !Number.isNaN(r.value))
    .sort((a, b) => b.value - a.value);
  return typeof limit === "number" ? rows.slice(0, limit) : rows;
}

/** GroupBy breakdown with multiple measures → rows keyed by friendly names. */
export function breakdownMulti(
  resultSet: RS | null | undefined,
  nameKey: string,
  series: Record<string, string>
): { data: Record<string, any>[]; categories: string[] } {
  if (!resultSet) return { data: [], categories: [] };
  const categories = Object.values(series);
  const data = resultSet.tablePivot().map((row) => {
    const out: Record<string, any> = { name: String(cell(row, nameKey) ?? "—") };
    for (const [key, name] of Object.entries(series)) {
      out[name] = Number(cell(row, key) ?? 0);
    }
    return out;
  });
  return { data, categories };
}

/** Merge multiple same-grain time series result sets into one chart dataset. */
export function mergeTrends(
  parts: { rs: RS | null | undefined; series: Record<string, string> }[]
): { data: Record<string, any>[]; categories: string[] } {
  const categories = Array.from(
    new Set(parts.flatMap((p) => Object.values(p.series)))
  );
  const byDate = new Map<string, Record<string, any>>();
  for (const part of parts) {
    for (const [key, name] of Object.entries(part.series)) {
      for (const row of part.rs?.chartPivot() ?? []) {
        const bucket = byDate.get(row.x) ?? { date: row.x };
        bucket[name] = Number(cell(row, key) ?? 0);
        byDate.set(row.x, bucket);
      }
    }
  }
  const data = Array.from(byDate.values()).sort((a, b) =>
    String(a.date).localeCompare(String(b.date))
  );
  for (const d of data) for (const c of categories) if (d[c] == null) d[c] = 0;
  return { data, categories };
}