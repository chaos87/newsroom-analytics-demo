"use client";

import { useMemo } from "react";
import { useCubeQuery } from "@cubejs-client/react";
import { PageHeader } from "@/components/app/page-header";
import { KpiCard } from "@/components/app/kpi-card";
import { ChartCard, QueryState } from "@/components/app/chart-card";
import { useDateRange, grainForRange } from "@/components/app/date-range-context";
import { num, trend, breakdown } from "@/lib/cube-data";
import { formatPercent, formatDuration } from "@/lib/format";
import { AreaChart as TremorAreaChart } from "@/components/AreaChart/AreaChart";
import { BarList } from "@/components/BarList/BarList";
import { DonutChart as TremorDonutChart } from "@/components/DonutChart/DonutChart";

const READER_COLORS = ["gray", "emerald", "accent"] as const;

export default function OverviewPage() {
  const { dateRange } = useDateRange();
  const grain = grainForRange(dateRange);
  const range = useMemo(() => [dateRange.from, dateRange.to] as [string, string], [dateRange]);

  // KPIs
  const sessions = useCubeQuery({
    measures: ["sessions.sessions", "sessions.activeUsers", "sessions.avgEngagedTimePerSession"],
    timeDimensions: [{ dimension: "sessions.eventDate", dateRange: range }],
  });
  const pageviews = useCubeQuery({
    measures: ["pages.pageviews"],
    timeDimensions: [{ dimension: "pages.eventDate", dateRange: range }],
  });
  const newSubs = useCubeQuery({
    measures: ["crm.newSubscribers"],
    timeDimensions: [{ dimension: "crm.subscriptionDate", dateRange: range }],
  });
  const paywall = useCubeQuery({
    measures: ["paywall.impressions", "paywall.clicks", "paywall.ctr"],
    timeDimensions: [{ dimension: "paywall.eventDate", dateRange: range }],
  });
  const funnel = useCubeQuery({
    measures: ["paywallFunnel.sessionsExposed", "paywallFunnel.paywallConversionRate"],
    timeDimensions: [{ dimension: "paywallFunnel.eventDate", dateRange: range }],
  });

  // Trend: sessions + pageviews (session grain)
  const trendQ = useCubeQuery({
    measures: ["sessions.sessions", "sessions.pageviews"],
    timeDimensions: [{ dimension: "sessions.eventDate", dateRange: range, granularity: grain }],
  });
  const trendData = trend(trendQ.resultSet, {
    "Sessions.sessions": "Sessions",
    "Sessions.pageviews": "Pageviews",
  });

  // Channels
  const channelsQ = useCubeQuery({
    measures: ["traffic.sessions"],
    dimensions: ["traffic.channelGrouping"],
    timeDimensions: [{ dimension: "traffic.eventDate", dateRange: range }],
  });
  const channels = breakdown(channelsQ.resultSet, "Traffic.channelGrouping", "Traffic.sessions");

  // Reader type split of article pageviews
  const readersQ = useCubeQuery({
    measures: ["readerTypes.articlePageviews"],
    dimensions: ["readerTypes.readerType"],
    timeDimensions: [{ dimension: "readerTypes.eventDate", dateRange: range }],
  });
  const readers = breakdown(readersQ.resultSet, "ReaderTypes.readerType", "ReaderTypes.articlePageviews");

  const ctr = num(paywall.resultSet, "Paywall.ctr");
  const conversion = num(funnel.resultSet, "PaywallFunnel.paywallConversionRate");

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="The Meridian Post"
        title="Overview"
        subtitle="How the paper is doing — audience, engagement and the subscription engine."
      />

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
        <KpiCard label="Sessions" value={num(sessions.resultSet, "Sessions.sessions")} />
        <KpiCard label="Active Users" value={num(sessions.resultSet, "Sessions.activeUsers")} />
        <KpiCard label="Pageviews" value={num(pageviews.resultSet, "Pages.pageviews")} />
        <KpiCard
          label="New Subscribers"
          value={num(newSubs.resultSet, "Crm.newSubscribers")}
          accent
        />
        <KpiCard label="Paywall CTR" value={ctr} format="percent" />
        <KpiCard label="Session Conv. Rate" value={conversion} format="percent" />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <ChartCard
          title="Audience trend"
          subtitle={`Sessions and pageviews by ${grain}`}
          grow
          className="lg:col-span-2"
        >
          <QueryState isLoading={trendQ.isLoading} isEmpty={trendData.data.length === 0}>
            <TremorAreaChart
              data={trendData.data}
              index="date"
              categories={trendData.categories}
              colors={["gray", "amber"]}
              autoMinValue
              showGridLines
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="Where sessions come from" subtitle="By default channel grouping" grow>
          <QueryState isLoading={channelsQ.isLoading} isEmpty={channels.length === 0}>
            <TremorDonutChart
              data={channels}
              category="name"
              value="value"
              colors={["gray", "amber", "emerald", "blue", "violet", "pink", "cyan"]}
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="Who is reading" subtitle="Article pageviews by reader type" grow>
          <QueryState isLoading={readersQ.isLoading} isEmpty={readers.length === 0}>
            <TremorDonutChart
              data={readers}
              category="name"
              value="value"
              colors={["gray", "emerald", "accent"]}
            />
          </QueryState>
        </ChartCard>
      </div>

      <p className="text-xs text-ink-soft">
        Engaged time per session:{" "}
        <span className="font-medium text-ink">
          {formatDuration(num(sessions.resultSet, "Sessions.avgEngagedTimePerSession"))}
        </span>{" "}
        · Sessions exposed to the paywall:{" "}
        <span className="font-medium text-ink">
          {(num(funnel.resultSet, "PaywallFunnel.sessionsExposed") ?? 0).toLocaleString()}
        </span>
      </p>
    </div>
  );
}