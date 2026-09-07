"use client";

import type { ReactNode } from "react";
import { Card } from "@/components/Card/Card";

export function ChartCard({
  title,
  subtitle,
  children,
  className,
  grow,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
  className?: string;
  grow?: boolean;
}) {
  return (
    <Card className={"p-5 " + (className ?? "")}>
      <p className="text-sm font-medium text-ink">{title}</p>
      {subtitle ? <p className="mt-0.5 text-xs text-ink-soft">{subtitle}</p> : null}
      <div className={"mt-4 " + (grow ? "h-72" : "")}>{children}</div>
    </Card>
  );
}

export function LoadingBlock({ height = 288 }: { height?: number }) {
  return (
    <div className="flex items-center justify-center" style={{ height }}>
      <div className="h-3 w-3 animate-pulse rounded-full bg-newspine" />
    </div>
  );
}

export function EmptyNote() {
  return (
    <p className="py-16 text-center text-sm text-ink-soft">No data in this range.</p>
  );
}

export function QueryState({
  isLoading,
  isEmpty,
  children,
}: {
  isLoading: boolean;
  isEmpty: boolean;
  children: ReactNode;
}) {
  if (isLoading) return <LoadingBlock />;
  if (isEmpty) return <EmptyNote />;
  return <>{children}</>;
}