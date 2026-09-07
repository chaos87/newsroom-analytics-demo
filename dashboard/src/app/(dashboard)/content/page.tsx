"use client";

import { useMemo } from "react";
import { useCubeQuery } from "@cubejs-client/react";
import { PageHeader } from "@/components/app/page-header";
import { KpiCard } from "@/components/app/kpi-card";
import { ChartCard, QueryState } from "@/components/app/chart-card";
import { useDateRange } from "@/components/app/date-range-context";
import { num, breakdown, breakdownMulti } from "@/lib/cube-data";
import { formatPercent } from "@/lib/format";
import { formattedNumber } from "@/utils/number-format";
import { BarChart } from "@/components/BarChart/BarChart";
import { BarList } from "@/components/BarList/BarList";
import { DonutWithLegend } from "@/components/app/donut-with-legend";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeaderCell,
  TableRow,
} from "@/components/Table/Table";

export default function ContentPage() {
  const { dateRange } = useDateRange();
  const range = useMemo(() => [dateRange.from, dateRange.to] as [string, string], [dateRange]);

  const totals = useCubeQuery({
    measures: [
      "articles.articlePageviews",
      "articles.shares",
      "articles.bookmarks",
      "articles.comments",
      "articles.avgScrollPercent",
    ],
    timeDimensions: [{ dimension: "articles.eventDate", dateRange: range }],
  });
  const publishedQ = useCubeQuery({
    measures: ["content.articlesPublished"],
    timeDimensions: [{ dimension: "content.publicationDate", dateRange: range }],
  });
  const inventoryQ = useCubeQuery({
    measures: ["contentTotals.numberOfArticles"],
    timeDimensions: [{ dimension: "contentTotals.asOfDate", dateRange: [range[1], range[1]] }],
  });

  const bySectionQ = useCubeQuery({
    measures: ["articles.articlePageviews"],
    dimensions: ["articles.section"],
    timeDimensions: [{ dimension: "articles.eventDate", dateRange: range }],
  });
  const bySection = breakdown(bySectionQ.resultSet, "Articles.section", "Articles.articlePageviews");

  const topArticlesQ = useCubeQuery({
    measures: ["articles.articlePageviews"],
    dimensions: ["articles.title"],
    timeDimensions: [{ dimension: "articles.eventDate", dateRange: range }],
    order: { "articles.articlePageviews": "desc" },
    limit: 10,
  });
  const topArticles = breakdown(topArticlesQ.resultSet, "Articles.title", "Articles.articlePageviews");

  const readersQ = useCubeQuery({
    measures: ["readerTypes.articlePageviews"],
    dimensions: ["readerTypes.readerType"],
    timeDimensions: [{ dimension: "readerTypes.eventDate", dateRange: range }],
  });
  const readers = breakdown(readersQ.resultSet, "ReaderTypes.readerType", "ReaderTypes.articlePageviews");

  const authorsQ = useCubeQuery({
    measures: [
      "articles.articlePageviews",
      "articles.engagedTime",
      "articles.shares",
      "articles.bookmarks",
      "articles.comments",
    ],
    dimensions: ["articles.author"],
    timeDimensions: [{ dimension: "articles.eventDate", dateRange: range }],
  });
  const authors = breakdownMulti(authorsQ.resultSet, "Articles.author", {
    "Articles.articlePageviews": "Pageviews",
    "Articles.engagedTime": "Engaged time",
    "Articles.shares": "Shares",
    "Articles.bookmarks": "Bookmarks",
    "Articles.comments": "Comments",
  });
  const authorRows = [...authors.data].sort(
    (a, b) => (b.Pageviews as number) - (a.Pageviews as number)
  );

  const scroll = num(totals.resultSet, "Articles.avgScrollPercent");

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="The Meridian Post"
        title="Content"
        subtitle="What the newsroom publishes and what readers actually read."
      />

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
        <KpiCard label="Article Pageviews" value={num(totals.resultSet, "Articles.articlePageviews")} />
        <KpiCard label="Avg Scroll Depth" value={scroll == null ? null : scroll / 100} format="percent" />
        <KpiCard label="Shares" value={num(totals.resultSet, "Articles.shares")} />
        <KpiCard label="Bookmarks" value={num(totals.resultSet, "Articles.bookmarks")} />
        <KpiCard label="Published (in range)" value={num(publishedQ.resultSet, "Content.articlesPublished")} />
        <KpiCard label="Total Articles" value={num(inventoryQ.resultSet, "ContentTotals.numberOfArticles")} />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <ChartCard title="Pageviews by section" subtitle="Article pageviews in range" grow>
          <QueryState isLoading={bySectionQ.isLoading} isEmpty={bySection.length === 0}>
            <BarChart
              data={bySection.map((s) => ({ name: s.name, Pageviews: s.value }))}
              index="name"
              categories={["Pageviews"]}
              colors={["gray"]}
              autoMinValue
            />
          </QueryState>
        </ChartCard>

        <ChartCard title="Who reads the paper" subtitle="Article pageviews by reader type" grow>
          <QueryState isLoading={readersQ.isLoading} isEmpty={readers.length === 0}>
            <DonutWithLegend data={readers} colors={["gray", "emerald", "accent"]} />
          </QueryState>
        </ChartCard>

        <ChartCard title="Top articles" subtitle="Most-read pieces in range" grow className="lg:col-span-2">
          <QueryState isLoading={topArticlesQ.isLoading} isEmpty={topArticles.length === 0}>
            <BarList data={topArticles} valueFormatter={(v: number) => formattedNumber(v)} />
          </QueryState>
        </ChartCard>

        <ChartCard
          title="Author league table"
          subtitle="Pageviews, engagement and interaction per byline"
          className="lg:col-span-2"
        >
          <QueryState isLoading={authorsQ.isLoading} isEmpty={authorRows.length === 0}>
            <Table>
              <TableHead>
                <TableRow>
                  <TableHeaderCell>Author</TableHeaderCell>
                  <TableHeaderCell className="text-right">Pageviews</TableHeaderCell>
                  <TableHeaderCell className="text-right">Shares</TableHeaderCell>
                  <TableHeaderCell className="text-right">Bookmarks</TableHeaderCell>
                  <TableHeaderCell className="text-right">Comments</TableHeaderCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {authorRows.map((row) => (
                  <TableRow key={String(row.name)}>
                    <TableCell className="font-medium">{String(row.name)}</TableCell>
                    <TableCell className="text-right tabular-nums">
                      {formattedNumber(row.Pageviews as number)}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {formattedNumber(row.Shares as number)}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {formattedNumber(row.Bookmarks as number)}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {formattedNumber(row.Comments as number)}
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
