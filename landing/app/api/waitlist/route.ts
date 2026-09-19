import { NextRequest, NextResponse } from "next/server";
import { promises as fs } from "fs";
import path from "path";

export const runtime = "nodejs";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type WaitlistEntry = {
  email: string;
  joinedAt: string;
};

export async function POST(request: NextRequest) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }

  const { email } = (body ?? {}) as { email?: unknown };
  if (typeof email !== "string" || !EMAIL_RE.test(email.trim())) {
    return NextResponse.json({ error: "Please enter a valid email address." }, { status: 400 });
  }

  const normalized = email.trim().toLowerCase();
  const entry: WaitlistEntry = { email: normalized, joinedAt: new Date().toISOString() };

  try {
    const dir = path.join(process.cwd(), "data");
    await fs.mkdir(dir, { recursive: true });
    const file = path.join(dir, "waitlist.json");
    let list: WaitlistEntry[] = [];
    try {
      const raw = await fs.readFile(file, "utf8");
      list = JSON.parse(raw);
    } catch {
      list = [];
    }

    if (!list.some((item) => item.email === normalized)) {
      list.push(entry);
      await fs.writeFile(file, JSON.stringify(list, null, 2), "utf8");
    }
  } catch {
    // Persistence must never break the signup UX. Vercel's filesystem is
    // ephemeral; production should point this at a database. We still
    // acknowledge the join so the visitor gets confirmed.
  }

  return NextResponse.json({ ok: true });
}