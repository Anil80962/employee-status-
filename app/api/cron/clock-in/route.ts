import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

const GITHUB_API = "https://api.github.com";

// If CRON_SECRET is set, verify it. If not set, allow through (Vercel Hobby
// cron jobs are already internal — the endpoint only triggers a workflow dispatch).
function verifyCron(req: NextRequest): boolean {
  const secret = process.env.CRON_SECRET?.trim();
  if (!secret) return true; // no secret configured → open
  const auth = req.headers.get("authorization");
  return auth === `Bearer ${secret}`;
}

export async function GET(req: NextRequest) {
  if (!verifyCron(req)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const token = process.env.GITHUB_TOKEN;
  const repo  = process.env.GITHUB_REPO;
  if (!token || !repo) {
    return NextResponse.json({ error: "GITHUB_TOKEN or GITHUB_REPO not configured" }, { status: 500 });
  }

  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "Content-Type": "application/json",
    "User-Agent": "asanify-cron/1.0",
  };

  const res = await fetch(
    `${GITHUB_API}/repos/${repo}/actions/workflows/clock-in.yml/dispatches`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({ ref: "main", inputs: { dry_run: "false" } }),
    }
  );

  if (!res.ok && res.status !== 204) {
    const text = await res.text();
    return NextResponse.json({ error: `GitHub API error: ${res.status} — ${text}` }, { status: 500 });
  }

  const istTime = new Intl.DateTimeFormat("en-IN", {
    timeZone: "Asia/Kolkata",
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date());

  console.log(`[Vercel cron] Clock-in triggered at ${istTime} IST`);
  return NextResponse.json({ ok: true, triggeredAt: istTime });
}
