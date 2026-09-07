"use client";

import { useEffect, useMemo, useState } from "react";
import cube, { type CubeApi } from "@cubejs-client/core";
import { CubeProvider } from "@cubejs-client/react";

const API_URL = process.env.NEXT_PUBLIC_CUBEJS_API_URL ?? "";

export function CubeApiProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetch("/api/cube-token")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error("token fetch failed"))))
      .then((d) => { if (!cancelled) setToken(d.token); })
      .catch(() => { if (!cancelled) setToken(""); });
    return () => { cancelled = true; };
  }, []);

  const cubeApi = useMemo<CubeApi | null>(() => {
    if (!token) return null;
    return cube(token, { apiUrl: `${API_URL}/cubejs-api/v1` });
  }, [token]);

  if (!cubeApi) return null; // simple gate; charts render once token is in

  return <CubeProvider cubeApi={cubeApi}>{children}</CubeProvider>;
}