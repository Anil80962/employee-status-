import { GITHUB_API } from "@/lib/github";

export interface Employee {
  id: string;
  name: string;
  enabled: boolean;
  empcode?: string;
}

export interface RepoEmployees {
  _comment?: string;
  employees: Employee[];
}

interface GitHubFileContent {
  content: string;
  sha: string;
  encoding: string;
}

export async function getEmployeesFile(
  repo: string,
  headers: Record<string, string>
): Promise<{ data: RepoEmployees; sha: string }> {
  const res = await fetch(`${GITHUB_API}/repos/${repo}/contents/employees.json`, { headers });
  if (!res.ok) {
    if (res.status === 404) return { data: { employees: [] }, sha: "" };
    throw new Error(`GitHub API error: ${res.status}`);
  }
  const file = await res.json() as GitHubFileContent;
  const decoded = Buffer.from(file.content, "base64").toString("utf-8");
  const parsed = JSON.parse(decoded) as RepoEmployees;
  parsed.employees = (parsed.employees || []).map((e: Employee | string) => {
    if (typeof e === "string") return { id: e, name: e, enabled: true };
    return { ...e, enabled: e.enabled !== false };
  });
  return { data: parsed, sha: file.sha };
}

export async function saveEmployeesFile(
  repo: string,
  headers: Record<string, string>,
  data: RepoEmployees,
  sha: string,
  message: string
) {
  const body: Record<string, string> = {
    message,
    content: Buffer.from(JSON.stringify(data, null, 2)).toString("base64"),
  };
  if (sha) body.sha = sha;
  const res = await fetch(`${GITHUB_API}/repos/${repo}/contents/employees.json`, {
    method: "PUT",
    headers,
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Failed to update employees.json: ${res.status}`);
}
