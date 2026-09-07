"use client";

import { CubeApiProvider } from "./cube-api-provider";
import { DateRangeProvider } from "./date-range-context";

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <DateRangeProvider>
      <CubeApiProvider>{children}</CubeApiProvider>
    </DateRangeProvider>
  );
}