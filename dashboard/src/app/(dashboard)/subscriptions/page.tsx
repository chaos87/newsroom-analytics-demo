"use client";

import { useMemo } from "react";
import { useCubeQuery } from "@cubejs-client/react";
import { PageHeader } from "@/components/app/page-header";
import { KpiCard } from "@/components/app/kpi-card";
import { ChartCard, QueryState } from "@/components/app/chart-card";
import { useDateRange, grainForRange } from "@/components/app/date-range-context";
import { num, breakdown, mergeTrends, cell, formatChartDate } from "@/lib/cube-data";
import { formatPercent } from "@/lib/format";
import { formattedNumber } from "@/utils/number-format";
import { BarChart } from "@/components/BarChart/BarChart";
import { BarList } from "@/components/BarList/BarList";
import { DonutWithLegend } from "@/components/app/donut-with-legend";
import { AreaChart } from "@/components/AreaChart/AreaChart";
import { Badge } from "@/components/Badge/Badge";

export default function SubscriptionsPage() {
  const { dateRange } = useDateRange();
  const grain = grainForRange(dateRange);
  const range = useMemo(() => [dateRange.from, dateRange.to] as [string, string], [dateRange]);

  const newSubsQ = useCubeQuery({
    measures: ["crm.newSubscribers"],
    timeDimensions: [{ dimension: "crm.subscriptionDate", dateRange: range }],
  });
  const churnsQ = useCubeQuery({
    measures: ["crm.newChurns"],
    timeDimensions: [{ dimension: "crm.churnDate", dateRange: range }],
  });
  const registeredQ = useCubeQuery({
    measures: ["crm.newRegisteredUsers"],
    timeDimensions: [{ dimension: "crm.registrationDate", dateRange: range }],
  });
  const totalsQ = useCubeQuery({
    measures: [
      "crmTotals.numberOfSubscribers",
      "crmTotals.numberOfRegisteredUsers",
      "crmTotals.cumulativeChurns",
    ],
    timeDimensions: [{ dimension: "crmTotals.asOfDate", dateRange: [range[1], range[1]] }],
  });
  const funnelQ = useCubeQuery({
    measures: ["paywallFunnel.sessionsExposed", "paywallFunnel.paywallConversionRate"],
    timeDimensions: [{ dimension: "paywallFunnel.eventDate", dateRange: range }],
  });

  // New subs vs churn, by month — merged from two date-grained queries
  const subsTrendQ = useCubeQuery({
    measures: ["crm.newSubscribers"],
    timeDimensions: [{ dimension: "crm.subscriptionDate", dateRange: range, granularity: grain }],
  });
  const churnTrendQ = useCubeQuery({
    measures: ["crm.newChurns"],
    timeDimensions: [{ dimension: "crm.churnDate", dateRange: range, granularity: grain }],
  });
  const subsVsChurn = mergeTrends(
    [
      { rs: subsTrendQ.resultSet, series: { "Crm.newSubscribers": "New subscribers" } },
      { rs: churnTrendQ.resultSet, series: { "Crm.newChurns": "Churns" } },
    ],
    grain
  );

  // Cumulative base over time
  const cumulativeQ = useCubeQuery({
    measures: ["crmTotals.cumulativeSubscribers"],
    timeDimensions: [{ dimension: "crmTotals.asOfDate", dateRange: range, granularity: grain }],
  });

  const tierQ = useCubeQuery({
    measures: ["subscriptions.newSubscribers"],
    dimensions: ["subscriptions.tier"],
    timeDimensions: [{ dimension: "subscriptions.subscriptionDate", dateRange: range }],
  });
  const tiers = breakdown(tierQ.resultSet, "Subscriptions.tier", "Subscriptions.newSubscribers");

  const channelQ = useCubeQuery({
    measures: ["subscriptions.newSubscribers"],
    dimensions: ["subscriptions.channelGrouping"],
    timeDimensions: [{ dimension: "subscriptions.subscriptionDate", dateRange: range }],
  });
  const channels = breakdown(channelQ.resultSet, "Subscriptions.channelGrouping", "Subscriptions.newSubscribers");

  const pathQ = useCubeQuery({
    measures: ["subscriptions.newSubscribers"],
    dimensions: ["subscriptions.purchasedSameDay"],
    timeDimensions: [{ dimension: "subscriptions.subscriptionDate", dateRange: range }],
  });
  const path = breakdown(
    pathQ.resultSet,
    "Subscriptions.purchasedSameDay",
    "Subscriptions.newSubscribers"
  );

  const newSubs = num(newSubsQ.resultSet, "Crm.newSubscribers") ?? 0;
  const churns = num(churnsQ.resultSet, "Crm.newChurns") ?? 0;
  const activeSubs = num(totalsQ.resultSet, "CrmTotals.numberOfSubscribers");
  const registered = num(totalsQ.resultSet, "CrmTotals.numberOfRegisteredUsers");

  const cumulativeData = (cumulativeQ.resultSet?.chartPivot() ?? []).map(
    (row: Record<string, any>) => ({
      date: formatChartDate(row.x, grain),
      Subscribers: Number(cell(row, "CrmTotals.cumulativeSubscribers") ?? 0),
    })
  );

  const sameDay = path.find((p) => String(p.name) === "true")?.value ?? 0;
  const later = path.find((p) => String(p.name) === "false")?.value ?? 0;

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="The Meridian Post"
        title="Subscriptions"
        subtitle="Growing the paying base faster than it churns — the business of the paper."
      />

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
        <KpiCard label="New Subscribers" value={newSubs} accent />
        <KpiCard label="New Churns" value={churns} />
        <KpiCard label="Net New" value={newSubs - churns} accent />
        <KpiCard label="Active Subscribers" value={activeSubs} />
        <KpiCard label="Registered Users" value={registered} />
        <KpiCard label="Session Conv. Rate" value={num(funnelQ.resultSet, "PaywallFunnel.paywallConversionRate")} format="percent" />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <ChartCard title="New subscribers vs churns" subtitle={`By ${grain}`} grow>
          <QueryState isLoading={subsTrendQ.isLoading} isEmpty={subsVsChurn.data.length === 0}>
            <BarChart
              data={subsVsChurn.data}
              index="date"
              categories={subsVsChurn.categories}
              colors={["accent", "gray"]}
              type="stacked"
              autoMinValue
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="The paying base" subtitle="Cumulative active subscribers (churn-aware)" grow>
          <QueryState isLoading={cumulativeQ.isLoading} isEmpty={cumulativeData.length === 0}>
            <AreaChart
              data={cumulativeData}
              index="date"
              categories={["Subscribers"]}
              colors={["accent"]}
              autoMinValue
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="What they buy" subtitle="New subscribers by tier" grow>
          <QueryState isLoading={tierQ.isLoading} isEmpty={tiers.length === 0}>
            <DonutWithLegend data={tiers} colors={["accent", "gray", "emerald"]} />
          </QueryState>
        </ChartCard>

        <ChartCard title="Where subs come from" subtitle="New subscribers by purchase-session channel" grow>
          <QueryState isLoading={channelQ.isLoading} isEmpty={channels.length === 0}>
            <BarList data={channels} valueFormatter={(v: number) => formattedNumber(v)} />
          </QueryState>
        </ChartCard>

        <ChartCard
          title="Conversion paths"
          subtitle="When readers hit by a paywall decide to subscribe"
          className="lg:col-span-2"
        >
          <div className="flex flex-wrap items-center gap-4 pt-1">
            <Badge variant="neutral">{sameDay} same-day</Badge>
            <Badge variant="neutral">{later} on a later visit</Badge>
            <p className="text-sm text-ink-soft">
              {formatPercent(sameDay / Math.max(sameDay + later, 1), 1)} of new subscribers convert in
              the same session they first hit the wall.
            </p>
          </div>
        </ChartCard>
      </div>
    </div>
  );
}
