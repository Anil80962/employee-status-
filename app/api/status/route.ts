import { NextRequest, NextResponse } from "next/server";
import { getGitHubHeaders, getRepo, GITHUB_API } from "@/lib/github";

export const dynamic = "force-dynamic";

/** Get today's date string in IST (YYYY-MM-DD) */
function getTodayIST(): string {
  const now = new Date();
  const istOffset = 5.5 * 60 * 60 * 1000; // IST = UTC+5:30
  const istDate = new Date(now.getTime() + istOffset);
  return istDate.toISOString().split("T")[0];
}

function getDayName(dateStr: string): string {
  const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  // Parse YYYY-MM-DD as local date components to avoid timezone shifting
  const [y, m, d] = dateStr.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  return days[date.getDay()];
}

function isWeekend(dateStr: string): boolean {
  const day = getDayName(dateStr);
  return day === "Saturday" || day === "Sunday";
}

interface Employee {
  id: string;
  name: string;
  empcode?: string;
}

interface WorkflowRun {
  id: number;
  status: string;
  conclusion: string | null;
  created_at: string;
  html_url: string;
}

interface WorkflowJob {
  id: number;
  name: string;
  status: string;
  conclusion: string | null;
  started_at: string | null;
  completed_at: string | null;
  steps: Array<{
    name: string;
    conclusion: string | null;
    number: number;
  }>;
}

async function fetchEmployees(repo: string, headers: Record<string, string>): Promise<Employee[]> {
  try {
    const res = await fetch(`${GITHUB_API}/repos/${repo}/contents/employees.json`, { headers });
    if (!res.ok) return [];
    const data = await res.json() as { content: string };
    const decoded = Buffer.from(data.content, "base64").toString("utf-8");
    return JSON.parse(decoded) as Employee[];
  } catch {
    return [];
  }
}

async function fetchHolidays(repo: string, headers: Record<string, string>): Promise<string[]> {
  try {
    const res = await fetch(`${GITHUB_API}/repos/${repo}/contents/holidays.json`, { headers });
    if (!res.ok) return [];
    const data = await res.json() as { content: string };
    const decoded = Buffer.from(data.content, "base64").toString("utf-8");
    const holidays = JSON.parse(decoded) as Array<{ date: string; label: string }>;
    return holidays.map((h) => h.date);
  } catch {
    return [];
  }
}

/** Map job conclusion to our status type */
function mapConclusion(
  conclusion: string | null,
  status: string
): "success" | "failure" | "skipped" | "pending" {
  if (status === "in_progress" || status === "queued" || status === "waiting") return "pending";
  if (conclusion === "success") return "success";
  if (conclusion === "failure" || conclusion === "timed_out") return "failure";
  if (conclusion === "skipped" || conclusion === "cancelled") return "skipped";
  return "pending";
}

/** Try to extract clock-in time from job steps */
function extractClockTime(job: WorkflowJob, jobStartedAt: string | null): string | null {
  if (job.conclusion !== "success") return null;
  if (jobStartedAt) {
    try {
      const d = new Date(jobStartedAt);
      return d.toLocaleTimeString("en-IN", {
        timeZone: "Asia/Kolkata",
        hour: "2-digit",
        minute: "2-digit",
        hour12: true,
      }) + " IST";
    } catch {
      return null;
    }
  }
  return null;
}

export async function GET(req: NextRequest) {
  try {
    const headers = getGitHubHeaders();
    const repo = getRepo();
    const { searchParams } = new URL(req.url);
    const wantRuns = searchParams.get("runs") === "1";

    const todayIST = getTodayIST();
    const dayName = getDayName(todayIST);
    const weekend = isWeekend(todayIST);

    // Fetch employees and holidays in parallel
    const [employees, holidayDates] = await Promise.all([
      fetchEmployees(repo, headers),
      fetchHolidays(repo, headers),
    ]);

    const isHoliday = holidayDates.includes(todayIST);
    const isWorkingDay = !weekend && !isHoliday;

    // Fetch recent workflow runs (last 10 to find today's)
    const runsUrl = `${GITHUB_API}/repos/${repo}/actions/runs?per_page=10&event=schedule`;
    const manualRunsUrl = `${GITHUB_API}/repos/${repo}/actions/runs?per_page=10&event=workflow_dispatch`;

    const [runsRes, manualRunsRes] = await Promise.all([
      fetch(runsUrl, { headers }),
      fetch(manualRunsUrl, { headers }),
    ]);

    interface GitHubRunsResponse {
      workflow_runs: WorkflowRun[];
    }

    const runsData = runsRes.ok ? (await runsRes.json() as GitHubRunsResponse) : { workflow_runs: [] };
    const manualRunsData = manualRunsRes.ok ? (await manualRunsRes.json() as GitHubRunsResponse) : { workflow_runs: [] };

    // Combine and sort by created_at desc
    const allRuns: WorkflowRun[] = [
      ...(runsData.workflow_runs ?? []),
      ...(manualRunsData.workflow_runs ?? []),
    ].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

    // Find today's latest run
    const todayRuns = allRuns.filter((r) => r.created_at.startsWith(todayIST));
    const latestTodayRun = todayRuns[0] ?? null;

    let employeeStatuses: Array<{
      id: string;
      name: string;
      conclusion: "success" | "failure" | "skipped" | "pending" | null;
      clockTime: string | null;
    }> = employees.map((emp) => ({
      id: emp.id,
      name: emp.name,
      conclusion: isWorkingDay ? "pending" : "skipped",
      clockTime: null,
    }));

    let lastRunAt: string | null = null;
    let lastRunId: number | null = null;

    if (latestTodayRun) {
      lastRunAt = latestTodayRun.created_at;
      lastRunId = latestTodayRun.id;

      // Fetch jobs for this run
      const jobsRes = await fetch(
        `${GITHUB_API}/repos/${repo}/actions/runs/${latestTodayRun.id}/jobs`,
        { headers }
      );

      if (jobsRes.ok) {
        interface GitHubJobsResponse {
          jobs: WorkflowJob[];
        }
        const jobsData = await jobsRes.json() as GitHubJobsResponse;
        const jobs: WorkflowJob[] = jobsData.jobs ?? [];

        employeeStatuses = employees.map((emp) => {
          // Match job by employee id — job name typically contains employee id
          const job = jobs.find(
            (j) =>
              j.name.toLowerCase().includes(emp.id.toLowerCase()) ||
              j.name.toLowerCase().includes(emp.name.toLowerCase().split(" ")[0])
          );

          if (!job) {
            return {
              id: emp.id,
              name: emp.name,
              conclusion: isWorkingDay ? "pending" : "skipped",
              clockTime: null,
            };
          }

          const conclusion = mapConclusion(job.conclusion, job.status);
          const clockTime = conclusion === "success" ? extractClockTime(job, job.started_at) : null;

          return {
            id: emp.id,
            name: emp.name,
            conclusion,
            clockTime,
          };
        });
      }
    }

    // Build recent runs for admin panel
    let recentRuns: Array<{
      id: number;
      status: string;
      conclusion: string | null;
      created_at: string;
      html_url: string;
      jobs?: Array<{
        id: number;
        name: string;
        conclusion: "success" | "failure" | "skipped" | "pending" | null;
        clockTime: string | null;
      }>;
    }> = [];

    if (wantRuns) {
      const last7 = allRuns.slice(0, 7);
      recentRuns = await Promise.all(
        last7.map(async (run) => {
          try {
            const jobsRes = await fetch(
              `${GITHUB_API}/repos/${repo}/actions/runs/${run.id}/jobs`,
              { headers }
            );
            if (!jobsRes.ok) {
              return { ...run, jobs: [] };
            }
            interface GitHubJobsResponse2 {
              jobs: WorkflowJob[];
            }
            const jobsData = await jobsRes.json() as GitHubJobsResponse2;
            const jobs: WorkflowJob[] = jobsData.jobs ?? [];
            return {
              id: run.id,
              status: run.status,
              conclusion: run.conclusion,
              created_at: run.created_at,
              html_url: run.html_url,
              jobs: jobs.map((j) => ({
                id: j.id,
                name: j.name,
                conclusion: mapConclusion(j.conclusion, j.status),
                clockTime:
                  j.conclusion === "success"
                    ? extractClockTime(j, j.started_at)
                    : null,
              })),
            };
          } catch {
            return { id: run.id, status: run.status, conclusion: run.conclusion, created_at: run.created_at, html_url: run.html_url, jobs: [] };
          }
        })
      );
    }

    return NextResponse.json({
      todayIST,
      dayName,
      isWorkingDay,
      employees: employeeStatuses,
      lastRunAt,
      lastRunId,
      ...(wantRuns ? { recentRuns } : {}),
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
