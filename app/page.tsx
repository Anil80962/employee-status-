"use client";

import { useState, useEffect, useCallback } from "react";

// ─── Types ───────────────────────────────────────────────────────────────────

interface EmployeeStatus {
  id: string;
  name: string;
  conclusion: "success" | "failure" | "skipped" | "pending" | null;
  clockTime: string | null;
}

interface StatusData {
  todayIST: string;
  dayName: string;
  isWorkingDay: boolean;
  employees: EmployeeStatus[];
  lastRunAt: string | null;
  lastRunId: number | null;
}

interface Employee {
  id: string;
  name: string;
  enabled: boolean;
  empcode?: string;
}

interface Holiday {
  date: string;
  label: string;
}

interface WorkflowRun {
  id: number;
  status: string;
  conclusion: string | null;
  created_at: string;
  html_url: string;
  jobs?: EmployeeStatus[];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const SESSION_KEY = "asanify_admin";

function saveSession(password: string) {
  sessionStorage.setItem(SESSION_KEY, JSON.stringify({ ok: true, password, ts: Date.now() }));
}
function loadSession(): { password: string } | null {
  try {
    const s = sessionStorage.getItem(SESSION_KEY);
    if (!s) return null;
    const parsed = JSON.parse(s);
    // 8-hour expiry
    if (Date.now() - parsed.ts > 8 * 60 * 60 * 1000) { sessionStorage.removeItem(SESSION_KEY); return null; }
    return parsed;
  } catch { return null; }
}
function clearSession() { sessionStorage.removeItem(SESSION_KEY); }

// ─── Status Badge ─────────────────────────────────────────────────────────────

function StatusBadge({ conclusion }: { conclusion: EmployeeStatus["conclusion"] }) {
  if (conclusion === "success")
    return <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-900/60 px-3 py-1 text-sm font-medium text-emerald-300 ring-1 ring-emerald-700">✅ Clocked In</span>;
  if (conclusion === "failure")
    return <span className="inline-flex items-center gap-1.5 rounded-full bg-red-900/60 px-3 py-1 text-sm font-medium text-red-300 ring-1 ring-red-700">❌ Failed</span>;
  if (conclusion === "skipped")
    return <span className="inline-flex items-center gap-1.5 rounded-full bg-slate-700/60 px-3 py-1 text-sm font-medium text-slate-300 ring-1 ring-slate-600">⏭ Skipped</span>;
  return <span className="inline-flex items-center gap-1.5 rounded-full bg-amber-900/60 px-3 py-1 text-sm font-medium text-amber-300 ring-1 ring-amber-700">⏳ Pending</span>;
}

function RunBadge({ conclusion }: { conclusion: string | null }) {
  const map: Record<string, string> = {
    success: "bg-emerald-900/60 text-emerald-300 ring-emerald-700",
    failure: "bg-red-900/60 text-red-300 ring-red-700",
    cancelled: "bg-slate-700/60 text-slate-300 ring-slate-600",
  };
  const cls = map[conclusion ?? ""] ?? "bg-amber-900/60 text-amber-300 ring-amber-700";
  return <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ${cls}`}>{conclusion ?? "in_progress"}</span>;
}

// ─── Toggle Switch ────────────────────────────────────────────────────────────

function Toggle({ enabled, onChange, disabled }: { enabled: boolean; onChange: (v: boolean) => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={enabled}
      disabled={disabled}
      onClick={() => onChange(!enabled)}
      className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none ${enabled ? "bg-emerald-600" : "bg-slate-600"} ${disabled ? "opacity-50 cursor-not-allowed" : ""}`}
    >
      <span className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ${enabled ? "translate-x-5" : "translate-x-0"}`} />
    </button>
  );
}

// ─── Status Tab ──────────────────────────────────────────────────────────────

function StatusTab() {
  const [data, setData] = useState<StatusData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchStatus = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const res = await fetch("/api/status");
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setData(await res.json());
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to load");
    } finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchStatus(); const t = setInterval(fetchStatus, 60_000); return () => clearInterval(t); }, [fetchStatus]);

  if (loading) return (
    <div className="flex items-center justify-center py-24">
      <div className="h-8 w-8 animate-spin rounded-full border-2 border-slate-600 border-t-indigo-500" />
      <span className="ml-3 text-slate-400">Fetching status…</span>
    </div>
  );

  if (error) return (
    <div className="rounded-lg bg-red-900/30 border border-red-700 p-6 text-center text-red-300">
      <p className="font-semibold">Failed to load status</p>
      <p className="mt-1 text-sm opacity-75">{error}</p>
      <button onClick={fetchStatus} className="mt-4 rounded-md bg-red-800 px-4 py-2 text-sm font-medium text-red-100 hover:bg-red-700 transition-colors">Retry</button>
    </div>
  );

  if (!data) return null;

  const ok = data.employees.filter(e => e.conclusion === "success").length;
  const fail = data.employees.filter(e => e.conclusion === "failure").length;

  return (
    <div className="space-y-6">
      <div className="rounded-xl bg-slate-800/50 border border-slate-700 p-5 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <div className="text-2xl font-bold text-slate-100">
            {data.dayName}, {new Date(data.todayIST + "T00:00:00").toLocaleDateString("en-IN", { day: "numeric", month: "long", year: "numeric" })}
          </div>
          <div className="mt-1 text-sm text-slate-400">
            {data.isWorkingDay
              ? <span className="text-emerald-400 font-medium">Working Day</span>
              : <span className="text-slate-500 font-medium">Non-Working Day</span>}
            {data.lastRunAt && (
              <span className="ml-3 text-slate-500">
                Last run: {new Date(data.lastRunAt).toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit" })} IST
              </span>
            )}
          </div>
        </div>
        <div className="flex gap-3">
          {[{ n: ok, label: "Clocked In", c: "emerald" }, { n: fail, label: "Failed", c: "red" }, { n: data.employees.length, label: "Total", c: "slate" }].map(({ n, label, c }) => (
            <div key={label} className={`rounded-lg bg-${c}-900/40 px-4 py-2 text-center border border-${c}-800`}>
              <div className={`text-xl font-bold text-${c}-300`}>{n}</div>
              <div className={`text-xs text-${c}-500`}>{label}</div>
            </div>
          ))}
        </div>
      </div>

      <div className="rounded-xl bg-slate-800/50 border border-slate-700 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-700 flex items-center justify-between">
          <h2 className="font-semibold text-slate-200">Employee Clock-In Status</h2>
          <button onClick={fetchStatus} className="text-xs text-slate-400 hover:text-slate-200 flex items-center gap-1.5 transition-colors">
            <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
            Refresh
          </button>
        </div>
        {data.employees.length === 0
          ? <div className="py-12 text-center text-slate-500">No active employees</div>
          : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-700 text-left">
                    <th className="px-5 py-3 font-medium text-slate-400">Employee</th>
                    <th className="px-5 py-3 font-medium text-slate-400">Status</th>
                    <th className="px-5 py-3 font-medium text-slate-400">Clock-In Time</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-700/50">
                  {data.employees.map(emp => (
                    <tr key={emp.id} className="hover:bg-slate-700/20 transition-colors">
                      <td className="px-5 py-3.5 font-medium text-slate-200">{emp.name || emp.id}</td>
                      <td className="px-5 py-3.5"><StatusBadge conclusion={emp.conclusion} /></td>
                      <td className="px-5 py-3.5 text-slate-300">{emp.clockTime ?? <span className="text-slate-600">—</span>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
      </div>
    </div>
  );
}

// ─── Admin Login ──────────────────────────────────────────────────────────────

function AdminLogin({ onLogin }: { onLogin: (pwd: string) => void }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true); setError("");
    try {
      const res = await fetch("/api/auth", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });
      if (res.ok) { saveSession(password); onLogin(password); }
      else { const d = await res.json(); setError(d.error || "Invalid credentials"); }
    } catch { setError("Network error. Please try again."); }
    finally { setLoading(false); }
  };

  return (
    <div className="flex items-center justify-center py-16">
      <div className="w-full max-w-sm">
        <div className="rounded-xl bg-slate-800/50 border border-slate-700 p-8">
          <div className="mb-6 text-center">
            <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-indigo-900/50 border border-indigo-700">
              <svg className="h-6 w-6 text-indigo-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
                <path d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold text-slate-100">Admin Login</h2>
            <p className="mt-1 text-sm text-slate-400">Enter your credentials to continue</p>
          </div>
          <form onSubmit={handleSubmit} className="space-y-4">
            <input
              type="text"
              value={username}
              onChange={e => setUsername(e.target.value)}
              placeholder="Username"
              autoComplete="username"
              className="w-full rounded-lg bg-slate-900 border border-slate-600 px-4 py-2.5 text-slate-100 placeholder-slate-500 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              autoFocus
            />
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="Password"
              autoComplete="current-password"
              className="w-full rounded-lg bg-slate-900 border border-slate-600 px-4 py-2.5 text-slate-100 placeholder-slate-500 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
            />
            {error && <p className="text-sm text-red-400">{error}</p>}
            <button
              type="submit"
              disabled={loading || !username || !password}
              className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 font-medium text-white hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {loading ? "Signing in…" : "Sign In"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

// ─── Admin Dashboard ──────────────────────────────────────────────────────────

function AdminDashboard({ adminPassword, onLogout }: { adminPassword: string; onLogout: () => void }) {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [empLoading, setEmpLoading] = useState(true);
  const [togglingId, setTogglingId] = useState<string | null>(null);
  const [addForm, setAddForm] = useState({ id: "", name: "", session: "", empcode: "" });
  const [empSaving, setEmpSaving] = useState(false);
  const [empError, setEmpError] = useState("");

  const [holidays, setHolidays] = useState<Holiday[]>([]);
  const [holLoading, setHolLoading] = useState(true);
  const [addHol, setAddHol] = useState({ date: "", label: "" });
  const [holSaving, setHolSaving] = useState(false);
  const [holError, setHolError] = useState("");

  const [triggerLoading, setTriggerLoading] = useState(false);
  const [triggerMsg, setTriggerMsg] = useState("");
  const [runs, setRuns] = useState<WorkflowRun[]>([]);
  const [runsLoading, setRunsLoading] = useState(true);

  const authHeader = { "x-admin-password": adminPassword, "Content-Type": "application/json" };

  const fetchEmployees = useCallback(async () => {
    setEmpLoading(true);
    try { const r = await fetch("/api/employees"); if (r.ok) setEmployees(await r.json()); }
    finally { setEmpLoading(false); }
  }, []);

  const fetchHolidays = useCallback(async () => {
    setHolLoading(true);
    try { const r = await fetch("/api/holidays"); if (r.ok) setHolidays(await r.json()); }
    finally { setHolLoading(false); }
  }, []);

  const fetchRuns = useCallback(async () => {
    setRunsLoading(true);
    try { const r = await fetch("/api/status?runs=1"); if (r.ok) { const d = await r.json(); setRuns(d.recentRuns ?? []); } }
    finally { setRunsLoading(false); }
  }, []);

  useEffect(() => { fetchEmployees(); fetchHolidays(); fetchRuns(); }, [fetchEmployees, fetchHolidays, fetchRuns]);

  // Toggle auto clock-in on/off
  const toggleEmployee = async (id: string, enabled: boolean) => {
    setTogglingId(id);
    try {
      const r = await fetch(`/api/employees/${id}`, {
        method: "PATCH",
        headers: authHeader,
        body: JSON.stringify({ enabled }),
      });
      if (r.ok) await fetchEmployees();
      else { const d = await r.json(); alert(d.error || "Failed to update"); }
    } finally { setTogglingId(null); }
  };

  const removeEmployee = async (id: string, name: string) => {
    if (!confirm(`Remove ${name}? Their secrets will remain in GitHub (delete manually if needed).`)) return;
    const r = await fetch(`/api/employees/${id}`, { method: "DELETE", headers: authHeader });
    if (r.ok) fetchEmployees(); else alert("Failed to remove employee");
  };

  const addEmployee = async (e: React.FormEvent) => {
    e.preventDefault();
    const { id, name, session, empcode } = addForm;
    if (!id || !name || !session || !empcode) return;
    setEmpSaving(true); setEmpError("");
    try {
      const r = await fetch("/api/employees", {
        method: "POST",
        headers: authHeader,
        body: JSON.stringify({ id, name, session, empcode }),
      });
      if (r.ok) { setAddForm({ id: "", name: "", session: "", empcode: "" }); fetchEmployees(); }
      else { const d = await r.json(); setEmpError(d.error || "Failed"); }
    } catch { setEmpError("Network error"); }
    finally { setEmpSaving(false); }
  };

  const addHoliday = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!addHol.date || !addHol.label) return;
    setHolSaving(true); setHolError("");
    try {
      const r = await fetch("/api/holidays", {
        method: "POST",
        headers: authHeader,
        body: JSON.stringify(addHol),
      });
      if (r.ok) { setAddHol({ date: "", label: "" }); fetchHolidays(); }
      else { const d = await r.json(); setHolError(d.error || "Failed"); }
    } catch { setHolError("Network error"); }
    finally { setHolSaving(false); }
  };

  const removeHoliday = async (date: string) => {
    if (!confirm(`Remove holiday on ${date}?`)) return;
    const r = await fetch(`/api/holidays/${date}`, { method: "DELETE", headers: authHeader });
    if (r.ok) fetchHolidays(); else alert("Failed to remove holiday");
  };

  const triggerWorkflow = async (dryRun: boolean) => {
    setTriggerLoading(true); setTriggerMsg("");
    try {
      const r = await fetch("/api/trigger", { method: "POST", headers: authHeader, body: JSON.stringify({ dryRun }) });
      if (r.ok) { setTriggerMsg(dryRun ? "Dry run triggered!" : "Clock-in triggered!"); setTimeout(fetchRuns, 4000); }
      else { const d = await r.json(); setTriggerMsg(`Error: ${d.error || "Failed"}`); }
    } catch { setTriggerMsg("Network error"); }
    finally { setTriggerLoading(false); }
  };

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-slate-200">Admin Panel</h2>
        <button onClick={onLogout} className="text-sm text-slate-400 hover:text-slate-200 flex items-center gap-1.5 transition-colors">
          <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}><path d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
          Sign Out
        </button>
      </div>

      {/* Employees */}
      <section className="rounded-xl bg-slate-800/50 border border-slate-700 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-700">
          <h3 className="font-semibold text-slate-200">Employees</h3>
          <p className="text-xs text-slate-400 mt-0.5">Toggle auto clock-in on/off per employee. Adding provisions GitHub Secrets automatically.</p>
        </div>
        <div className="p-5 space-y-4">
          {empLoading
            ? <div className="flex items-center gap-2 text-slate-400 text-sm"><div className="h-4 w-4 animate-spin rounded-full border-2 border-slate-600 border-t-indigo-500" />Loading…</div>
            : employees.length === 0
              ? <p className="text-sm text-slate-500">No employees yet.</p>
              : (
                <div className="space-y-2">
                  {employees.map(emp => (
                    <div key={emp.id} className="flex items-center justify-between rounded-lg bg-slate-900/50 border border-slate-700 px-4 py-3">
                      <div className="flex items-center gap-3 min-w-0">
                        <Toggle
                          enabled={emp.enabled}
                          disabled={togglingId === emp.id}
                          onChange={(v) => toggleEmployee(emp.id, v)}
                        />
                        <div className="min-w-0">
                          <span className="font-medium text-slate-200">{emp.name}</span>
                          <span className="ml-2 font-mono text-xs text-slate-500">{emp.id}</span>
                          <span className={`ml-2 text-xs font-medium ${emp.enabled ? "text-emerald-500" : "text-slate-500"}`}>
                            {emp.enabled ? "Auto clock-in ON" : "Auto clock-in OFF"}
                          </span>
                        </div>
                      </div>
                      <button
                        onClick={() => removeEmployee(emp.id, emp.name)}
                        className="ml-4 flex-shrink-0 rounded-md bg-red-900/30 px-3 py-1 text-xs font-medium text-red-400 hover:bg-red-900/60 transition-colors"
                      >
                        Remove
                      </button>
                    </div>
                  ))}
                </div>
              )}

          <form onSubmit={addEmployee} className="rounded-lg bg-slate-900/30 border border-slate-700 p-4 space-y-3">
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">Add Employee</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {[
                { key: "name", placeholder: "Full Name" },
                { key: "id", placeholder: "Short ID (e.g. priya)" },
                { key: "empcode", placeholder: "Asanify Employee Code" },
              ].map(({ key, placeholder }) => (
                <input
                  key={key}
                  value={addForm[key as keyof typeof addForm]}
                  onChange={e => setAddForm(f => ({ ...f, [key]: e.target.value }))}
                  placeholder={placeholder}
                  className="rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              ))}
              <input
                value={addForm.session}
                onChange={e => setAddForm(f => ({ ...f, session: e.target.value }))}
                placeholder="Session Base64 (from npm run capture)"
                className="rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 font-mono text-xs sm:col-span-2"
              />
            </div>
            {empError && <p className="text-xs text-red-400">{empError}</p>}
            <button
              type="submit"
              disabled={empSaving || !addForm.id || !addForm.name || !addForm.session || !addForm.empcode}
              className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {empSaving ? "Adding…" : "Add Employee"}
            </button>
          </form>
        </div>
      </section>

      {/* Holidays */}
      <section className="rounded-xl bg-slate-800/50 border border-slate-700 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-700">
          <h3 className="font-semibold text-slate-200">Holidays</h3>
          <p className="text-xs text-slate-400 mt-0.5">Clock-in is skipped on these dates for everyone.</p>
        </div>
        <div className="p-5 space-y-4">
          {holLoading
            ? <div className="flex items-center gap-2 text-slate-400 text-sm"><div className="h-4 w-4 animate-spin rounded-full border-2 border-slate-600 border-t-indigo-500" />Loading…</div>
            : holidays.length === 0
              ? <p className="text-sm text-slate-500">No holidays configured.</p>
              : (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-2">
                  {holidays.slice().sort((a, b) => a.date.localeCompare(b.date)).map(h => (
                    <div key={h.date} className="flex items-center justify-between rounded-lg bg-slate-900/50 border border-slate-700 px-3 py-2.5">
                      <div>
                        <span className="text-sm font-medium text-slate-200">{h.label}</span>
                        <span className="ml-2 text-xs text-slate-500">{h.date}</span>
                      </div>
                      <button onClick={() => removeHoliday(h.date)} className="ml-2 flex-shrink-0 text-slate-500 hover:text-red-400 transition-colors" title="Remove">
                        <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}><path d="M6 18L18 6M6 6l12 12" /></svg>
                      </button>
                    </div>
                  ))}
                </div>
              )}
          <form onSubmit={addHoliday} className="rounded-lg bg-slate-900/30 border border-slate-700 p-4 space-y-3">
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wide">Add Holiday</p>
            <div className="flex flex-col sm:flex-row gap-3">
              <input type="date" value={addHol.date} onChange={e => setAddHol(h => ({ ...h, date: e.target.value }))}
                className="rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-slate-100 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 [color-scheme:dark]" />
              <input value={addHol.label} onChange={e => setAddHol(h => ({ ...h, label: e.target.value }))} placeholder="Holiday name (e.g. Diwali)"
                className="flex-1 rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500" />
              <button type="submit" disabled={holSaving || !addHol.date || !addHol.label}
                className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors whitespace-nowrap">
                {holSaving ? "Adding…" : "Add Holiday"}
              </button>
            </div>
            {holError && <p className="text-xs text-red-400">{holError}</p>}
          </form>
        </div>
      </section>

      {/* Actions */}
      <section className="rounded-xl bg-slate-800/50 border border-slate-700 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-700">
          <h3 className="font-semibold text-slate-200">Actions</h3>
          <p className="text-xs text-slate-400 mt-0.5">Manually trigger the clock-in workflow.</p>
        </div>
        <div className="p-5 space-y-4">
          <div className="flex flex-wrap gap-3">
            <button onClick={() => triggerWorkflow(true)} disabled={triggerLoading}
              className="rounded-lg bg-amber-900/40 border border-amber-700 px-5 py-2.5 text-sm font-medium text-amber-300 hover:bg-amber-900/70 disabled:opacity-50 transition-colors">
              {triggerLoading ? "Triggering…" : "🧪 Trigger Dry Run"}
            </button>
            <button onClick={() => triggerWorkflow(false)} disabled={triggerLoading}
              className="rounded-lg bg-emerald-900/40 border border-emerald-700 px-5 py-2.5 text-sm font-medium text-emerald-300 hover:bg-emerald-900/70 disabled:opacity-50 transition-colors">
              {triggerLoading ? "Triggering…" : "🚀 Trigger Clock-In Now"}
            </button>
          </div>
          {triggerMsg && <p className={`text-sm ${triggerMsg.startsWith("Error") ? "text-red-400" : "text-emerald-400"}`}>{triggerMsg}</p>}
        </div>
      </section>

      {/* Recent Runs */}
      <section className="rounded-xl bg-slate-800/50 border border-slate-700 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-700 flex items-center justify-between">
          <div>
            <h3 className="font-semibold text-slate-200">Recent Workflow Runs</h3>
            <p className="text-xs text-slate-400 mt-0.5">Last 7 GitHub Actions runs</p>
          </div>
          <button onClick={fetchRuns} className="text-xs text-slate-400 hover:text-slate-200 flex items-center gap-1.5 transition-colors">
            <svg className="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
            Refresh
          </button>
        </div>
        <div className="p-5">
          {runsLoading
            ? <div className="flex items-center gap-2 text-slate-400 text-sm"><div className="h-4 w-4 animate-spin rounded-full border-2 border-slate-600 border-t-indigo-500" />Loading…</div>
            : runs.length === 0
              ? <p className="text-sm text-slate-500">No workflow runs found.</p>
              : (
                <div className="space-y-3">
                  {runs.map(run => (
                    <div key={run.id} className="rounded-lg bg-slate-900/50 border border-slate-700 p-4">
                      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                        <div className="flex items-center gap-3">
                          <RunBadge conclusion={run.conclusion} />
                          <a href={run.html_url} target="_blank" rel="noopener noreferrer" className="text-xs text-indigo-400 hover:text-indigo-300 transition-colors">View on GitHub ↗</a>
                        </div>
                        <span className="text-xs text-slate-500">
                          {new Date(run.created_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata", dateStyle: "medium", timeStyle: "short" })} IST
                        </span>
                      </div>
                      {run.jobs && run.jobs.length > 0 && (
                        <div className="mt-3 flex flex-wrap gap-2">
                          {run.jobs.map(job => (
                            <span key={job.id} className={`inline-flex items-center gap-1 rounded px-2 py-0.5 text-xs font-medium ${
                              job.conclusion === "success" ? "bg-emerald-900/40 text-emerald-300"
                              : job.conclusion === "failure" ? "bg-red-900/40 text-red-300"
                              : "bg-slate-700/40 text-slate-400"}`}>
                              {job.name}{job.clockTime && <span className="opacity-75">· {job.clockTime}</span>}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
        </div>
      </section>
    </div>
  );
}

// ─── Admin Tab wrapper ────────────────────────────────────────────────────────

function AdminTab() {
  const [adminPassword, setAdminPassword] = useState<string | null>(() => loadSession()?.password ?? null);

  if (!adminPassword) return <AdminLogin onLogin={setAdminPassword} />;
  return <AdminDashboard adminPassword={adminPassword} onLogout={() => { clearSession(); setAdminPassword(null); }} />;
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function Home() {
  const [activeTab, setActiveTab] = useState<"status" | "admin">("status");

  return (
    <div className="min-h-screen bg-slate-900">
      <header className="sticky top-0 z-10 border-b border-slate-700/50 bg-slate-900/90 backdrop-blur">
        <div className="mx-auto max-w-5xl px-4 sm:px-6">
          <div className="flex h-14 items-center gap-4">
            <div className="flex items-center gap-2.5">
              <div className="flex h-7 w-7 items-center justify-center rounded-md bg-indigo-600 text-sm font-bold text-white">A</div>
              <span className="font-semibold text-slate-100">Asanify HR</span>
              <span className="hidden sm:inline text-slate-600">·</span>
              <span className="hidden sm:inline text-sm text-slate-400">Auto Clock-In Dashboard</span>
            </div>
            <nav className="ml-auto flex items-center gap-1">
              {(["status", "admin"] as const).map(tab => (
                <button key={tab} onClick={() => setActiveTab(tab)}
                  className={`rounded-md px-3 py-1.5 text-sm font-medium capitalize transition-colors ${
                    activeTab === tab ? "bg-slate-700 text-slate-100" : "text-slate-400 hover:text-slate-200 hover:bg-slate-800"
                  }`}>
                  {tab}
                </button>
              ))}
            </nav>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-4 py-8 sm:px-6">
        {activeTab === "status" ? <StatusTab /> : <AdminTab />}
      </main>
      <footer className="border-t border-slate-800 py-6 text-center text-xs text-slate-600">
        Asanify HR Dashboard · Powered by GitHub Actions
      </footer>
    </div>
  );
}
