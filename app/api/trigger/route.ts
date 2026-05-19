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

// Discover the workflow file name (look for clock-in related workflows)
async function findWorkflowId(
  repo: string,
  headers: Record<string, string>
): Promise<number | string> {
  const res = await fetch(`${GITHUB_API}/repos/${repo}/actions/workflows`, { headers });
  if (!res.ok) throw new Error(`Failed to list workflows: ${res.status}`);

  interface WorkflowListResponse {
    workflows: Array<{ id: number; name: string; path: string; state: string }>;
  }

  const data = await res.json() as WorkflowListResponse;
  const workflows = data.workflows ?? [];

  // Look for clock-in or asanify workflow
  const clockInWorkflow = workflows.find(
    (w) =>
      w.state === "active" &&
      (w.name.toLowerCase().includes("clock") ||
        w.name.toLowerCase().includes("asanify") ||
        w.path.toLowerCase().includes("clock") ||
        w.path.toLowerCase().includes("asanify"))
  );

  if (clockInWorkflow) return clockInWorkflow.id;

  // Fall back to first active workflow
  const activeWorkflow = workflows.find((w) => w.state === "active");
  if (activeWorkflow) return activeWorkflow.id;

  throw new Error("No active workflow found in repository");
}

export async function POST(req: NextRequest) {
  try {
    // Verify admin password
    const adminPassword = process.env.ADMIN_PASSWORD;
    if (!adminPassword) {
      return NextResponse.json({ error: "ADMIN_PASSWORD not configured" }, { status: 500 });
    }

    const providedPassword = req.headers.get("x-admin-password");
    // Accept __verified__ token (set by client after login) or actual password
    if (providedPassword !== "__verified__" && providedPassword !== adminPassword) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json() as { dryRun?: boolean };
    const dryRun = body.dryRun === true;

    const headers = getGitHubHeaders();
    const repo = getRepo();

    const workflowId = await findWorkflowId(repo, headers);

    // Trigger workflow_dispatch
    const triggerRes = await fetch(
      `${GITHUB_API}/repos/${repo}/actions/workflows/${workflowId}/dispatches`,
      {
        method: "POST",
        headers,
        body: JSON.stringify({
          ref: "main",
          inputs: {
            dry_run: dryRun ? "true" : "false",
          },
        }),
      }
    );

    if (!triggerRes.ok && triggerRes.status !== 204) {
      const text = await triggerRes.text();
      throw new Error(`Failed to trigger workflow: ${triggerRes.status} — ${text}`);
    }

    return NextResponse.json({
      ok: true,
      message: dryRun ? "Dry run triggered" : "Clock-in workflow triggered",
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
