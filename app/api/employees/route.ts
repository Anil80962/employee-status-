import { NextRequest, NextResponse } from "next/server";
import { getEmployeesFile, saveEmployeesFile, type Employee } from "@/lib/employees";

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

async function getRepoPublicKey(repo: string, headers: Record<string, string>) {
  const res = await fetch(`${GITHUB_API}/repos/${repo}/actions/secrets/public-key`, { headers });
  if (!res.ok) throw new Error(`Failed to fetch public key: ${res.status}`);
  return res.json() as Promise<{ key_id: string; key: string }>;
}

async function encryptSecret(publicKey: string, secretValue: string): Promise<string> {
  const sodium = await import("libsodium-wrappers");
  await sodium.ready;
  const encryptedBytes = sodium.crypto_box_seal(
    Buffer.from(secretValue, "utf-8"),
    Buffer.from(publicKey, "base64")
  );
  return Buffer.from(encryptedBytes).toString("base64");
}

async function putSecret(
  repo: string,
  secretName: string,
  encryptedValue: string,
  keyId: string,
  headers: Record<string, string>
) {
  const res = await fetch(`${GITHUB_API}/repos/${repo}/actions/secrets/${secretName}`, {
    method: "PUT",
    headers,
    body: JSON.stringify({ encrypted_value: encryptedValue, key_id: keyId }),
  });
  if (!res.ok && res.status !== 201 && res.status !== 204) {
    throw new Error(`Failed to set secret ${secretName}: ${res.status}`);
  }
}

export async function GET() {
  try {
    const headers = getGitHubHeaders();
    const repo = getRepo();
    const { data } = await getEmployeesFile(repo, headers);
    return NextResponse.json(data.employees);
  } catch (e: unknown) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Unknown error" }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const adminPassword = process.env.ADMIN_PASSWORD;
    const provided = req.headers.get("x-admin-password");
    if (adminPassword && provided !== adminPassword) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json() as { id?: string; name?: string; session?: string; empcode?: string };
    const { id, name, session, empcode } = body;

    if (!id || !name || !session || !empcode) {
      return NextResponse.json({ error: "id, name, session, and empcode are required" }, { status: 400 });
    }
    if (!/^[a-zA-Z0-9_]+$/.test(id)) {
      return NextResponse.json({ error: "Employee ID must be alphanumeric (underscores allowed)" }, { status: 400 });
    }

    const headers = getGitHubHeaders();
    const repo = getRepo();
    const { data, sha } = await getEmployeesFile(repo, headers);

    if (data.employees.find((e) => e.id === id)) {
      return NextResponse.json({ error: `Employee "${id}" already exists` }, { status: 409 });
    }

    const newEmployee: Employee = { id, name, enabled: true, empcode };
    data.employees.push(newEmployee);
    await saveEmployeesFile(repo, headers, data, sha, `Add employee: ${name} (${id})`);

    const { key_id, key } = await getRepoPublicKey(repo, headers);
    const [encSession, encCode] = await Promise.all([
      encryptSecret(key, session),
      encryptSecret(key, empcode),
    ]);
    await Promise.all([
      putSecret(repo, `ASANIFY_STATE_${id.toUpperCase()}`, encSession, key_id, headers),
      putSecret(repo, `ASANIFY_EMPCODE_${id.toUpperCase()}`, encCode, key_id, headers),
    ]);

    return NextResponse.json({ ok: true, employee: newEmployee });
  } catch (e: unknown) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Unknown error" }, { status: 500 });
  }
}
