import { NextResponse } from "next/server";
import jwt from "jsonwebtoken";

const API_SECRET = process.env.CUBEJS_API_SECRET;

export async function GET() {
  if (!API_SECRET) {
    return NextResponse.json(
      { error: "CUBEJS_API_SECRET is not configured" },
      { status: 500 }
    );
  }
  // Long-lived read-only token: demo dataset, public dashboard, no PII.
  const token = jwt.sign({}, API_SECRET, { expiresIn: "7d" });
  return NextResponse.json({ token }, { headers: { "Cache-Control": "no-store" } });
}