"use client";

import { useMemo } from "react";
import { useCubeQuery } from "@cubejs-client/react";
import { PageHeader } from "@/components/app/page-header";
import { KpiCard } from "@/components/app/kpi-card";
import { ChartCard, QueryState } from "@/components/app/chart-card";
import { useDateRange, grainForRange } from "@/components/app/date-range-context";
import { num, trend, breakdown, cell } from "@/lib/cube-data";
import { formatPercent } from "@/lib/format";
import { BarChart } from "@/components/BarChart/BarChart";
import { BarList } from "@/components/BarList/BarList";
import { ProgressBar } from "@/components/ProgressBar/ProgressBar";
import { formattedNumber } from "@/utils/number-format";

export default function PaywallPage() {
  const { dateRange } = useDateRange();
  const grain = grainForRange(dateRange);
  const range = useMemo(() => [dateRange.from, dateRange.to] as [string, string], [dateRange]);

  const totals = useCubeQuery({
    measures: ["paywall.impressions", "paywall.clicks", "paywall.ctr"],
    timeDimensions: [
      { dimension: "paywall.eventDate", dateRange: range },
    ],
  });
  // paywallFunnel lives on its own eventDate; run a parallel total for it
  const funnelTotals = useCubeQuery({
    measures: [
      "paywallFunnel.sessionsExposed",
      "paywallFunnel.paywallConversionRate",
      "paywallFunnel.newSubscribers",
    ],
    timeDimensions: [{ dimension: "paywallFunnel.eventDate", dateRange: range }],
  });

  const byTypeQ = useCubeQuery({
    measures: ["paywall.impressions", "paywall.clicks", "paywall.ctr"],
    dimensions: ["paywall.paywallType"],
    timeDimensions: [{ dimension: "paywall.eventDate", dateRange: range }],
  });
  const byType = {
    data: (byTypeQ.resultSet?.tablePivot() ?? []).map((row: Record<string, any>) => ({
      name: String(cell(row, "Paywall.paywallType") ?? "—"),
      Impressions: Number(cell(row, "Paywall.impressions") ?? 0),
      Clicks: Number(cell(row, "Paywall.clicks") ?? 0),
    })),
    rows: (byTypeQ.resultSet?.tablePivot() ?? []).map((row: Record<string, any>) => ({
      name: String(cell(row, "Paywall.paywallType") ?? "—"),
      impressions: Number(cell(row, "Paywall.impressions") ?? 0),
      clicks: Number(cell(row, "Paywall.clicks") ?? 0),
      ctr: Number(cell(row, "Paywall.ctr") ?? 0),
    })),
  };

  const byOfferQ = useCubeQuery({
    measures: ["paywall.impressions", "paywall.clicks"],
    dimensions: ["paywall.bundleOffer"],
    timeDimensions: [{ dimension: "paywall.eventDate", dateRange: range }],
  });
  const byOffer = breakdown(byOfferQ.resultSet, "Paywall.bundleOffer", "Paywall.clicks");

  const trendQ = useCubeQuery({
    measures: ["paywallFunnel.impressions", "paywallFunnel.clicks", "paywallFunnel.ctr"],
    timeDimensions: [{ dimension: "paywallFunnel.eventDate", dateRange: range, granularity: grain }],
  });
  const trendData = trend(
    trendQ.resultSet,
    {
      "PaywallFunnel.impressions": "Impressions",
      "PaywallFunnel.clicks": "Clicks",
    },
    grain
  );
  const ctrTrend = trend(trendQ.resultSet, { "PaywallFunnel.ctr": "CTR" }, grain);

  const impressions = num(totals.resultSet, "Paywall.impressions") ?? 0;
  const clicks = num(totals.resultSet, "Paywall.clicks") ?? 0;
  const sameDaySubs = num(funnelTotals.resultSet, "PaywallFunnel.newSubscribers") ?? 0;

  const funnelSteps = [
    { label: "Paywall impressions", value: impressions },
    { label: "Paywall CTA clicks", value: clicks },
    { label: "Same-day subscribers", value: sameDaySubs },
  ];
  const funnelBase = Math.max(impressions, 1);

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="The Meridian Post"
        title="Paywall"
        subtitle="The subscription engine: which wall gets shown, which wall converts."
      />

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
        <KpiCard label="Impressions" value={impressions} />
        <KpiCard label="Clicks" value={clicks} />
        <KpiCard label="CTR" value={num(totals.resultSet, "Paywall.ctr")} format="percent" />
        <KpiCard label="Exposed Sessions" value={num(funnelTotals.resultSet, "PaywallFunnel.sessionsExposed")} />
        <KpiCard label="Session Conv. Rate" value={num(funnelTotals.resultSet, "PaywallFunnel.paywallConversionRate")} format="percent" accent />
        <KpiCard label="Same-Day Subs" value={sameDaySubs} accent />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <ChartCard
          title="Impression → click → subscribe"
          subtitle="Every conversion runs the full funnel in one session"
          className="lg:col-span-2"
        >
          <div className="space-y-5 pt-1">
            {funnelSteps.map((step) => (
              <div key={step.label}>
                <div className="mb-1.5 flex items-baseline justify-between">
                  <p className="text-sm text-ink">{step.label}</p>
                  <p className="text-sm font-medium tabular-nums text-ink">
                    {formattedNumber(step.value)}
                    <span className="ml-2 text-xs text-ink-soft">
                      {formatPercent(step.value / funnelBase, 1)} of impressions
                    </span>
                  </p>
                </div>
                <ProgressBar
                  value={(step.value / funnelBase) * 100}
                  variant="error"
                  aria-label={step.label}
                />
              </div>
            ))}
          </div>
        </ChartCard>

        <ChartCard title="Which wall converts" subtitle="Impressions & clicks by paywall type" grow>
          <QueryState isLoading={byTypeQ.isLoading} isEmpty={byType.data.length === 0}>
            <BarChart
              data={byType.data}
              index="name"
              categories={["Impressions", "Clicks"]}
              colors={["gray", "accent"]}
              autoMinValue
            />
            <div className="mt-3 flex gap-6">
              {byType.rows.map((row) => (
                <p key={row.name} className="text-xs text-ink-soft">
                  <span className="font-medium capitalize text-ink">{row.name}</span> CTR:{" "}
                  <span className="font-medium tabular-nums text-ink">
                    {formatPercent(row.ctr)}
                  </span>
                </p>
              ))}
            </div>
          </QueryState>
        </ChartCard>

        <ChartCard title="Bundle offers" subtitle="CTA clicks by offer bundle shown" grow>
          <QueryState isLoading={byOfferQ.isLoading} isEmpty={byOffer.length === 0}>
            <BarList
              data={byOffer}
              valueFormatter={(v: number) => formattedNumber(v)}
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="Paywall volume over time" subtitle={`Impressions and clicks by ${grain}`} grow>
          <QueryState isLoading={trendQ.isLoading} isEmpty={trendData.data.length === 0}>
            <BarChart
              data={trendData.data}
              index="date"
              categories={trendData.categories}
              colors={["gray", "accent"]}
              type="stacked"
              autoMinValue
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="CTR over time" subtitle={`Click-through rate by ${grain}`} grow>
          <QueryState isLoading={trendQ.isLoading} isEmpty={ctrTrend.data.length === 0}>
            <BarChart
              data={ctrTrend.data}
              index="date"
              categories={ctrTrend.categories}
              colors={["accent"]}
              autoMinValue
              valueFormatter={(v: number) => `${(v * 100).toFixed(2)}%`}
            />
          </QueryState>
        </ChartCard>
      </div>

      <p className="text-xs text-ink-soft">
        Hard walls block premium sections on every non-subscriber read; metered walls allow 3 free
        reads per month, then block. Lifestyle stays free. CTR{" "}
        {formatPercent(num(totals.resultSet, "Paywall.ctr"))} of impressions in this range.
      </p>
    </div>
  );
}