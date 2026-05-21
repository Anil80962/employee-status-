export const GITHUB_API = "https://api.github.com";

// Strip BOM (U+FEFF) and any other non-ASCII control chars that break fetch headers.
// Vercel CLI sometimes stores env vars with a leading BOM when piped via PowerShell.
function cleanEnv(value: string | undefined): string {
  if (!value) return "";
  return value.replace(/^﻿/, "").replace(/[^\x00-\xFF]/g, "").trim();
}

export function getGitHubToken(): string {
  const token = cleanEnv(process.env.GITHUB_TOKEN);
  if (!token) throw new Error("GITHUB_TOKEN not configured");
  return token;
}

export function getGitHubHeaders(): Record<string, string> {
  return {
    Authorization: `Bearer ${getGitHubToken()}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "asanify-dashboard/1.0",
    "Content-Type": "application/json",
  };
}

export function getRepo(): string {
  const repo = cleanEnv(process.env.GITHUB_REPO);
  if (!repo) throw new Error("GITHUB_REPO not configured");
  return repo;
}
