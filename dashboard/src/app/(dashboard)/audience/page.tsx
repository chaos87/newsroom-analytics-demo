"use client";

import { useMemo } from "react";
import { useCubeQuery } from "@cubejs-client/react";
import { PageHeader } from "@/components/app/page-header";
import { KpiCard } from "@/components/app/kpi-card";
import { ChartCard, QueryState } from "@/components/app/chart-card";
import { useDateRange, grainForRange } from "@/components/app/date-range-context";
import { num, trend, breakdown, breakdownMulti } from "@/lib/cube-data";
import { formattedNumber } from "@/lib/format";
import { AreaChart } from "@/components/AreaChart/AreaChart";
import { BarChart } from "@/components/BarChart/BarChart";
import { BarList } from "@/components/BarList/BarList";
import { DonutChart } from "@/components/DonutChart/DonutChart";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeaderCell,
  TableRow,
} from "@/components/Table/Table";

export default function AudiencePage() {
  const { dateRange } = useDateRange();
  const grain = grainForRange(dateRange);
  const range = useMemo(() => [dateRange.from, dateRange.to] as [string, string], [dateRange]);

  const totals = useCubeQuery({
    measures: [
      "sessions.sessions",
      "sessions.activeUsers",
      "sessions.avgEngagedTimePerSession",
      "sessions.pageviewsPerSession",
      "sessions.sessionsPerUser",
    ],
    timeDimensions: [{ dimension: "sessions.eventDate", dateRange: range }],
  });

  const trendQ = useCubeQuery({
    measures: ["sessions.sessions", "sessions.activeUsers"],
    timeDimensions: [{ dimension: "sessions.eventDate", dateRange: range, granularity: grain }],
  });
  const trendData = trend(trendQ.resultSet, {
    "Sessions.sessions": "Sessions",
    "Sessions.activeUsers": "Active users",
  });

  const channelsQ = useCubeQuery({
    measures: ["traffic.sessions", "traffic.pageviews", "traffic.engagedTime", "traffic.newsletterSignups"],
    dimensions: ["traffic.channelGrouping"],
    timeDimensions: [{ dimension: "traffic.eventDate", dateRange: range }],
  });
  const channels = breakdownMulti(channelsQ.resultSet, "Traffic.channelGrouping", {
    "Traffic.sessions": "Sessions",
    "Traffic.engagedTime": "Engaged time",
    "Traffic.newsletterSignups": "Newsletter signups",
  });

  const sourcesQ = useCubeQuery({
    measures: ["traffic.sessions"],
    dimensions: ["traffic.trafficSource"],
    timeDimensions: [{ dimension: "traffic.eventDate", dateRange: range }],
  });
  const sources = breakdown(sourcesQ.resultSet, "Traffic.trafficSource", "Traffic.sessions");

  const countriesQ = useCubeQuery({
    measures: ["sessions.sessions"],
    dimensions: ["sessions.country"],
    timeDimensions: [{ dimension: "sessions.eventDate", dateRange: range }],
  });
  const countries = breakdown(countriesQ.resultSet, "Sessions.country", "Sessions.sessions", 8);

  const devicesQ = useCubeQuery({
    measures: ["sessions.sessions"],
    dimensions: ["sessions.device"],
    timeDimensions: [{ dimension: "sessions.eventDate", dateRange: range }],
  });
  const devices = breakdown(devicesQ.resultSet, "Sessions.device", "Sessions.sessions");

  const campaignsQ = useCubeQuery({
    measures: ["traffic.sessions", "traffic.pageviews", "traffic.newsletterSignups"],
    dimensions: ["traffic.utmCampaign"],
    timeDimensions: [{ dimension: "traffic.eventDate", dateRange: range }],
  });
  const campaigns = breakdownMulti(campaignsQ.resultSet, "Traffic.utmCampaign", {
    "Traffic.sessions": "Sessions",
    "Traffic.pageviews": "Pageviews",
    "Traffic.newsletterSignups": "Signups",
  });
  const campaignRows = [...campaigns.data].sort(
    (a, b) => (b.Sessions as number) - (a.Sessions as number)
  );

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="The Meridian Post"
        title="Audience"
        subtitle="Where readers come from, what they read on, and how hard they lean in."
      />

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-5">
        <KpiCard label="Sessions" value={num(totals.resultSet, "Sessions.sessions")} />
        <KpiCard label="Active Users" value={num(totals.resultSet, "Sessions.activeUsers")} />
        <KpiCard
          label="Engaged / Session"
          value={num(totals.resultSet, "Sessions.avgEngagedTimePerSession")}
          format="duration"
        />
        <KpiCard
          label="Pages / Session"
          value={num(totals.resultSet, "Sessions.pageviewsPerSession")}
          format="decimal"
        />
        <KpiCard
          label="Sessions / User"
          value={num(totals.resultSet, "Sessions.sessionsPerUser")}
          format="decimal"
        />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <ChartCard title="Sessions & users over time" subtitle={`By ${grain}`} grow className="lg:col-span-2">
          <QueryState isLoading={trendQ.isLoading} isEmpty={trendData.data.length === 0}>
            <AreaChart
              data={trendData.data}
              index="date"
              categories={trendData.categories}
              colors={["gray", "amber"]}
              autoMinValue
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="Sessions by channel" subtitle="Default channel grouping" grow>
          <QueryState isLoading={channelsQ.isLoading} isEmpty={channels.data.length === 0}>
            <BarChart
              data={channels.data}
              index="name"
              categories={["Sessions"]}
              colors={["gray"]}
              autoMinValue
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="Top traffic sources" subtitle="Session first-click source" grow>
          <QueryState isLoading={sourcesQ.isLoading} isEmpty={sources.length === 0}>
            <BarList
              data={sources.slice(0, 8)}
              color="gray"
              valueFormatter={(v: number) => formattedNumber(v)}
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="Devices" subtitle="Sessions by device category" grow>
          <QueryState isLoading={devicesQ.isLoading} isEmpty={devices.length === 0}>
            <DonutChart
              data={devices}
              category="name"
              value="value"
              colors={["gray", "amber", "emerald"]}
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="Top countries" subtitle="Sessions by country" grow>
          <QueryState isLoading={countriesQ.isLoading} isEmpty={countries.length === 0}>
            <BarList
              data={countries}
              color="gray"
              valueFormatter={(v: number) => formattedNumber(v)}
            />
          </QueryState>
        </ChartCard>

        <ChartCard
          title="Campaign scorecard"
          subtitle="UTM-tagged sessions (untagged sessions shown as (none))"
          className="lg:col-span-2"
        >
          <QueryState isLoading={campaignsQ.isLoading} isEmpty={campaignRows.length === 0}>
            <Table>
              <TableHead>
                <TableRow>
                  <TableHeaderCell>Campaign</TableHeaderCell>
                  <TableHeaderCell className="text-right">Sessions</TableHeaderCell>
                  <TableHeaderCell className="text-right">Pageviews</TableHeaderCell>
                  <TableHeaderCell className="text-right">Newsletter signups</TableHeaderCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {campaignRows.map((row) => (
                  <TableRow key={String(row.name)}>
                    <TableCell className="font-medium">{String(row.name)}</TableCell>
                    <TableCell className="text-right tabular-nums">
                      {formattedNumber(row.Sessions as number)}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {formattedNumber(row.Pageviews as number)}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {formattedNumber(row.Signups as number)}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </QueryState>
        </ChartCard>
      </div>
    </div>
  );
}