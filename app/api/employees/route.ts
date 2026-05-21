import { NextRequest, NextResponse } from "next/server";
import { getEmployeesFile, saveEmployeesFile, type Employee } from "@/lib/employees";
import { getGitHubHeaders, getRepo, GITHUB_API } from "@/lib/github";

export const dynamic = "force-dynamic";

async function getRepoPublicKey(repo: string, headers: Record<string, string>) {
  const res = await fetch(`${GITHUB_API}/repos/${repo}/actions/secrets/public-key`, { headers });
  if (!res.ok) throw new Error(`Failed to fetch public key: ${res.status}`);
  return res.json() as Promise<{ key_id: string; key: string }>;
}

// Pure-JS implementation of NaCl crypto_box_seal (sealed box).
// Uses tweetnacl (X25519 DH + XSalsa20-Poly1305) + @noble/hashes (Blake2b nonce).
// No native modules — works on any JS runtime including Vercel Edge/Lambda.
async function encryptSecret(publicKeyB64: string, secretValue: string): Promise<string> {
  const nacl = (await import("tweetnacl")).default;
  const { blake2b } = await import("@noble/hashes/blake2.js");

  const recipientPK = new Uint8Array(Buffer.from(publicKeyB64, "base64"));
  const message     = new Uint8Array(Buffer.from(secretValue, "utf-8"));
  const ephemeral   = nacl.box.keyPair();

  // Nonce = Blake2b-256(ephemeral_pk || recipient_pk)[0:24]
  const nonceInput = new Uint8Array(64);
  nonceInput.set(ephemeral.publicKey, 0);
  nonceInput.set(recipientPK, 32);
  const nonce = blake2b(nonceInput, { dkLen: 24 });

  // Shared key via X25519 + HSalsa20 (nacl.box.before)
  const sharedKey = nacl.box.before(recipientPK, ephemeral.secretKey);

  // Encrypt with XSalsa20-Poly1305
  const encrypted = nacl.secretbox(message, nonce, sharedKey);

  // Sealed box = ephemeral_pk (32 bytes) || mac+ciphertext
  const result = new Uint8Array(32 + encrypted.length);
  result.set(ephemeral.publicKey, 0);
  result.set(encrypted, 32);
  return Buffer.from(result).toString("base64");
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
