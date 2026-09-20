import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const API_URL =
  process.env.GLOBMINT_API_URL?.replace(/\/$/, "") ||
  "https://globmint-backend.onrender.com";

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

  const res = await fetch(`${API_URL}/api/v1/waitlist`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: email.trim().toLowerCase() }),
    // The backend seeds real market rates from live feeds; give it a moment.
    signal: AbortSignal.timeout(8000),
  });

  if (!res.ok) {
    const data = await res.json().catch(() => null);
    return NextResponse.json(
      { error: data?.message ?? "Could not save your email. Please try again." },
      { status: res.status }
    );
  }

  return NextResponse.json({ ok: true });
}