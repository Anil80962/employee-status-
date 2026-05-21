import { NextRequest, NextResponse } from "next/server";
import { getGitHubHeaders, getRepo, GITHUB_API } from "@/lib/github";

export const dynamic = "force-dynamic";

interface Holiday {
  date: string;
  label: string;
}

interface GitHubFileContent {
  content: string;
  sha: string;
}

async function getHolidaysFile(
  repo: string,
  headers: Record<string, string>
): Promise<{ holidays: Holiday[]; sha: string }> {
  const res = await fetch(`${GITHUB_API}/repos/${repo}/contents/holidays.json`, { headers });
  if (!res.ok) {
    if (res.status === 404) return { holidays: [], sha: "" };
    throw new Error(`GitHub API error: ${res.status}`);
  }
  const data = await res.json() as GitHubFileContent;
  const decoded = Buffer.from(data.content, "base64").toString("utf-8");
  const parsed = JSON.parse(decoded);
  // Support both old flat array and new {holidays:[...]} object format
  const list: Holiday[] = Array.isArray(parsed) ? parsed : (parsed.holidays ?? []);
  return { holidays: list, sha: data.sha };
}

export async function GET() {
  try {
    const headers = getGitHubHeaders();
    const repo = getRepo();
    const { holidays } = await getHolidaysFile(repo, headers);
    return NextResponse.json(holidays);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json() as { date?: string; label?: string };
    const { date, label } = body;

    if (!date || !label) {
      return NextResponse.json({ error: "date and label are required" }, { status: 400 });
    }

    // Validate date format YYYY-MM-DD
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return NextResponse.json({ error: "date must be in YYYY-MM-DD format" }, { status: 400 });
    }

    const headers = getGitHubHeaders();
    const repo = getRepo();

    const { holidays, sha } = await getHolidaysFile(repo, headers);

    if (holidays.find((h) => h.date === date)) {
      return NextResponse.json({ error: `Holiday on ${date} already exists` }, { status: 409 });
    }

    const updatedHolidays = [...holidays, { date, label }].sort((a, b) =>
      a.date.localeCompare(b.date)
    );
    const newContent = Buffer.from(JSON.stringify(updatedHolidays, null, 2)).toString("base64");

    const updateBody: Record<string, string> = {
      message: `Add holiday: ${label} (${date})`,
      content: newContent,
    };
    if (sha) updateBody.sha = sha;

    const updateRes = await fetch(`${GITHUB_API}/repos/${repo}/contents/holidays.json`, {
      method: "PUT",
      headers,
      body: JSON.stringify(updateBody),
    });

    if (!updateRes.ok) {
      throw new Error(`Failed to update holidays.json: ${updateRes.status}`);
    }

    return NextResponse.json({ ok: true });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
