import { NextRequest, NextResponse } from "next/server";
import { getEmployeesFile, saveEmployeesFile } from "@/lib/employees";
import { getGitHubHeaders, getRepo } from "@/lib/github";

export const dynamic = "force-dynamic";

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await req.json() as { enabled?: boolean };
    if (typeof body.enabled !== "boolean") {
      return NextResponse.json({ error: "enabled (boolean) required" }, { status: 400 });
    }

    const headers = getGitHubHeaders();
    const repo = getRepo();
    const { data, sha } = await getEmployeesFile(repo, headers);

    const emp = data.employees.find((e) => e.id === id);
    if (!emp) return NextResponse.json({ error: `Employee "${id}" not found` }, { status: 404 });

    emp.enabled = body.enabled;
    await saveEmployeesFile(repo, headers, data, sha,
      `${body.enabled ? "Enable" : "Disable"} auto clock-in: ${emp.name} (${id})`);

    return NextResponse.json({ ok: true, employee: emp });
  } catch (e: unknown) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Unknown error" }, { status: 500 });
  }
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;

    const headers = getGitHubHeaders();
    const repo = getRepo();
    const { data, sha } = await getEmployeesFile(repo, headers);

    const emp = data.employees.find((e) => e.id === id);
    if (!emp) return NextResponse.json({ error: `Employee "${id}" not found` }, { status: 404 });

    data.employees = data.employees.filter((e) => e.id !== id);
    await saveEmployeesFile(repo, headers, data, sha, `Remove employee: ${emp.name} (${id})`);

    return NextResponse.json({ ok: true });
  } catch (e: unknown) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Unknown error" }, { status: 500 });
  }
}
