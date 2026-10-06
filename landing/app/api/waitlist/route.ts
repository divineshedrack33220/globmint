import { createHash } from "node:crypto";

import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const API_URL =
  process.env.GLOBMINT_API_URL?.replace(/\/$/, "") ||
  "https://globmint-backend.onrender.com";

// Landing-originated signups are attributed via the source column.
const SOURCE = "landing";

// Per-IP signup budget. The landing page never stores or forwards a raw IP;
// it keeps an in-memory count keyed by a one-way SHA-256 hash of the client
// IP. Best-effort per instance (serverless may reset it); the backend rate
// limiter remains the authoritative guard.
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const RATE_LIMIT_MAX = 5;
const rateWindows = new Map<string, { count: number; resetAt: number }>();

// clientIpHash returns a stable 32-hex SHA-256 digest of the client IP. When
// there is no usable address (streaming/proxy edge cases) it falls back to a
// per-request marker that still rate-limits but never exposes a real identity.
function clientIpHash(request: NextRequest): string {
  const forwarded = request.headers.get("x-forwarded-for");
  const ip =
    forwarded?.split(",")[0]?.trim() ||
    request.headers.get("x-real-ip") ||
    request.ip ||
    "unknown";
  return createHash("sha256").update(ip).digest("hex").slice(0, 32);
}

function rateLimited(ipHash: string): boolean {
  const now = Date.now();
  const entry = rateWindows.get(ipHash);
  if (!entry || now >= entry.resetAt) {
    rateWindows.set(ipHash, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return false;
  }
  entry.count += 1;
  return entry.count > RATE_LIMIT_MAX;
}

export async function POST(request: NextRequest) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }

  const { email } = (body ?? {}) as { email?: unknown };
  if (typeof email !== "string" || !EMAIL_RE.test(email.trim())) {
    return NextResponse.json(
      { error: "Please enter a valid email address." },
      { status: 400 }
    );
  }

  // Rate-limited or backend failures are not surfaced to the visitor: the
  // form promise is "we saved your email", and exposing the mechanics leaks
  // the backend topology. Only invalid input gets a 400.
  if (rateLimited(clientIpHash(request))) {
    return NextResponse.json({ ok: true });
  }

  try {
    await fetch(`${API_URL}/api/v1/waitlist`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: email.trim().toLowerCase(),
        source: SOURCE,
        ip_hash: clientIpHash(request),
        user_agent: request.headers.get("user-agent") || "",
      }),
      signal: AbortSignal.timeout(8000),
    });
  } catch {
    // Ignored: the visitor's email is still "saved" from their point of view.
  }

  return NextResponse.json({ ok: true });
}