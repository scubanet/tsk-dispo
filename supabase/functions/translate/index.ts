// AtollTalk Pro translation proxy.
//
// Keeps ANTHROPIC_API_KEY server-side. The app sends the StoreKit 2 signed
// transaction (jwsRepresentation); we verify it Deno-natively (JWS ES256
// signature via `jose`, x5c chain anchored to Apple's root CAs via
// `@peculiar/x509`), enforce a daily fair-use cap, then call Claude.
//
// Why not Apple's `app-store-server-library`? It verifies the cert chain with
// Node's `crypto.X509Certificate.prototype.verify()`, which the Supabase Edge
// (Deno) runtime does NOT implement (ERR_NOT_IMPLEMENTED) — so every JWS,
// Sandbox or Production, failed verification. WebCrypto-based verification works.
//
// Required secrets (supabase secrets set ...):
//   ANTHROPIC_API_KEY   - Claude key (never shipped in the app)
//   ATOLLTALK_BUNDLE_ID - e.g. swiss.atoll.talk
// Provided automatically by Supabase: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// Deploy with JWT off (we do our own auth): supabase functions deploy translate --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://esm.sh/jose@5.9.6";
import { cryptoProvider, X509Certificate } from "https://esm.sh/@peculiar/x509@1.12.3";

// @peculiar/x509 needs a WebCrypto engine; Deno's global `crypto` provides one.
cryptoProvider.set(crypto);

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const BUNDLE_ID = (Deno.env.get("ATOLLTALK_BUNDLE_ID") ?? "swiss.atoll.talk").trim();
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const PRODUCT_IDS = new Set([
  "swiss.atoll.talk.pro.monthly",
  "swiss.atoll.talk.pro.yearly",
  "swiss.atoll.talk.pro.lifetime", // Non-Consumable: permanent Pro
]);
const ALLOWED_MODELS = new Set([
  "claude-sonnet-4-6",
  "claude-haiku-4-5-20251001",
]);
const DEFAULT_MODEL = "claude-sonnet-4-6";
const DAILY_LIMIT = 2000; // per account fair-use cap

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

// Apple root CAs (DER) for chain anchoring — fetched once at cold start.
let appleRoots: Uint8Array[] | null = null;
async function loadAppleRoots(): Promise<Uint8Array[]> {
  if (appleRoots) return appleRoots;
  const urls = [
    "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
    "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer",
    "https://www.apple.com/appleca/AppleIncRootCertificate.cer",
  ];
  appleRoots = await Promise.all(
    urls.map(async (u) => new Uint8Array(await (await fetch(u)).arrayBuffer())),
  );
  return appleRoots;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

interface DecodedTx {
  bundleId?: string;
  productId?: string;
  environment?: string;
  expiresDate?: number; // ms epoch
  revocationDate?: number; // ms epoch
  originalTransactionId?: string;
}

// Verify the StoreKit 2 signed transaction (JWS) Deno-natively. Returns the
// decoded payload on success, or { tx: null, error } describing why it failed.
async function verifyTransaction(
  jws: string,
): Promise<{ tx: DecodedTx | null; error?: string }> {
  try {
    const roots = await loadAppleRoots();

    const header = jose.decodeProtectedHeader(jws) as { alg?: string; x5c?: string[] };
    if (header.alg !== "ES256") throw new Error(`unexpected alg ${header.alg}`);
    if (!header.x5c?.length) throw new Error("missing x5c chain");

    const chain = header.x5c.map((b64) => new X509Certificate(b64));

    // 1. Each cert in the provided chain is signed by the next one up.
    for (let i = 0; i < chain.length - 1; i++) {
      const ok = await chain[i].verify({
        publicKey: chain[i + 1].publicKey,
        signatureOnly: true,
      });
      if (!ok) throw new Error(`chain link ${i} signature invalid`);
    }

    // 2. Anchor the top of the chain to a TRUSTED Apple root we fetched
    //    ourselves — never trust the root the x5c provides on its own. Apple
    //    ships the root inside x5c, so it either equals one of ours or is
    //    signed by one.
    const rootCerts = roots.map((der) => new X509Certificate(der));
    const top = chain[chain.length - 1];
    const topRaw = new Uint8Array(top.rawData);
    let anchored = false;
    for (const r of rootCerts) {
      if (bytesEqual(topRaw, new Uint8Array(r.rawData))) { anchored = true; break; }
      if (await top.verify({ publicKey: r.publicKey, signatureOnly: true })) {
        anchored = true;
        break;
      }
    }
    if (!anchored) throw new Error("chain not anchored to a trusted Apple root");

    // 3. Every cert must be within its validity window.
    const now = Date.now();
    for (const c of chain) {
      if (now < c.notBefore.getTime() || now > c.notAfter.getTime()) {
        throw new Error("certificate outside validity window");
      }
    }

    // 4. The JWS signature itself, against the leaf certificate's public key.
    const leafKey = await jose.importX509(
      `-----BEGIN CERTIFICATE-----\n${header.x5c[0]}\n-----END CERTIFICATE-----`,
      "ES256",
    );
    const { payload } = await jose.compactVerify(jws, leafKey, { algorithms: ["ES256"] });
    const tx = JSON.parse(new TextDecoder().decode(payload)) as DecodedTx;

    // 5. Bundle id must match ours (Apple's library enforced this too).
    if (tx.bundleId !== BUNDLE_ID) throw new Error(`bundleId mismatch ${tx.bundleId}`);

    return { tx };
  } catch (e) {
    const error = (e as Error)?.message ?? String(e);
    console.error("verifyTransaction failed:", error);
    return { tx: null, error };
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (!ANTHROPIC_API_KEY) return json(500, { error: "server_misconfigured" });

  let body: {
    text?: string; source?: string; target?: string;
    context?: string; glossary?: string; model?: string; jws?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_json" });
  }

  const { text, target, context = "", glossary = "", jws } = body;
  if (!text || !target || !jws) return json(400, { error: "missing_fields" });

  // 1. Entitlement: verify the StoreKit 2 signed transaction. The reason for a
  //    failure is logged server-side (verifyTransaction), not leaked to clients.
  const { tx } = await verifyTransaction(jws);
  if (!tx) return json(403, { error: "verify_failed" });

  console.log("entitlement: verified productId=", tx.productId, "env=", tx.environment);
  if (!tx.productId || !PRODUCT_IDS.has(tx.productId)) {
    return json(403, { error: "wrong_product", productId: tx.productId });
  }
  if (tx.revocationDate) return json(403, { error: "revoked" });
  if (tx.expiresDate && tx.expiresDate < Date.now()) {
    return json(403, { error: "expired" });
  }

  // 2. Fair-use cap per account/day.
  const account = tx.originalTransactionId;
  const today = new Date().toISOString().slice(0, 10);
  const supa = createClient(SUPABASE_URL, SERVICE_ROLE);
  const { data: count, error: usageErr } = await supa.rpc("atolltalk_bump_usage", {
    p_account: account,
    p_day: today,
  });
  if (usageErr) return json(500, { error: "usage_failed" });
  if (typeof count === "number" && count > DAILY_LIMIT) {
    return json(429, { error: "rate_limited" });
  }

  // 3. Translate via Claude.
  const model = ALLOWED_MODELS.has(body.model ?? "") ? body.model! : DEFAULT_MODEL;
  let system = context;
  system += `\n\nÜbersetze den folgenden Text nach ${target}.`;
  if (glossary) system += `\n\nGlossar — diese Begriffe immer so übersetzen:\n${glossary}`;

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: 1024,
      system,
      messages: [{ role: "user", content: text }],
    }),
  });
  if (!res.ok) return json(502, { error: "upstream_failed", status: res.status });

  const data = await res.json();
  const out = (data?.content ?? [])
    .filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text)
    .join("")
    .trim();

  return json(200, { text: out });
});
