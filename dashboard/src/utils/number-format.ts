const compact = new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 1 });

export function compactNumber(value: number | null | undefined): string {
  if (value == null || Number.isNaN(value)) return "—";
  return compact.format(value);
}

export function formattedNumber(value: number | null | undefined, locale = "en-US"): string {
  if (value == null || Number.isNaN(value)) return "—";
  return new Intl.NumberFormat(locale).format(value);
}

export function formattedDate(date: string | Date): string {
  const d = typeof date === "string" ? new Date(date) : date;
  if (Number.isNaN(d.getTime())) return String(date);
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}