import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

const GITHUB_API = "https://api.github.com";

function getGitHubHeaders() {
  const token = process.env.GITHUB_TOKEN;
  if (!token) throw new Error("GITHUB_TOKEN not configured");
  return {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "asanify-dashboard/1.0",
    "Content-Type": "application/json",
  };
}

function getRepo() {
  const repo = process.env.GITHUB_REPO;
  if (!repo) throw new Error("GITHUB_REPO not configured");
  return repo;
}

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
  return { holidays: JSON.parse(decoded) as Holiday[], sha: data.sha };
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { date: string } }
) {
  try {
    const holidayDate = params.date;

    if (!holidayDate) {
      return NextResponse.json({ error: "Date required" }, { status: 400 });
    }

    const headers = getGitHubHeaders();
    const repo = getRepo();

    const { holidays, sha } = await getHolidaysFile(repo, headers);

    const index = holidays.findIndex((h) => h.date === holidayDate);
    if (index === -1) {
      return NextResponse.json({ error: `Holiday on "${holidayDate}" not found` }, { status: 404 });
    }

    const removedHoliday = holidays[index];
    const updatedHolidays = holidays.filter((h) => h.date !== holidayDate);
    const newContent = Buffer.from(JSON.stringify(updatedHolidays, null, 2)).toString("base64");

    const updateBody: Record<string, string> = {
      message: `Remove holiday: ${removedHoliday.label} (${holidayDate})`,
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
