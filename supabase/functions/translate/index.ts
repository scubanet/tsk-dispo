// AtollTalk Pro translation proxy.
//
// Keeps ANTHROPIC_API_KEY server-side. The app sends the StoreKit 2 signed
// transaction (jwsRepresentation); we verify it with Apple's official
// app-store-server-library (x5c chain anchored to Apple root CAs), enforce a
// daily fair-use cap, then call Claude and return the translation.
//
// Required secrets (supabase secrets set ...):
//   ANTHROPIC_API_KEY   - Claude key (never shipped in the app)
//   ATOLLTALK_BUNDLE_ID - e.g. swiss.atoll.talk
//   APP_APPLE_ID        - numeric App Store app id (needed for Production verify)
// Provided automatically by Supabase: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// Deploy with JWT off (we do our own auth): supabase functions deploy translate --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  SignedDataVerifier,
  Environment,
} from "https://esm.sh/@apple/app-store-server-library@1.4.0";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const BUNDLE_ID = Deno.env.get("ATOLLTALK_BUNDLE_ID") ?? "swiss.atoll.talk";
const APP_APPLE_ID = Number(Deno.env.get("APP_APPLE_ID") ?? "0") || undefined;
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
  const certs = await Promise.all(
    urls.map(async (u) => new Uint8Array(await (await fetch(u)).arrayBuffer())),
  );
  appleRoots = certs;
  return certs;
}

// Verify the signed transaction, trying Production then Sandbox.
async function verifyTransaction(jws: string) {
  const roots = await loadAppleRoots();
  for (const env of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      const verifier = new SignedDataVerifier(
        roots,
        false, // enableOnlineChecks off — avoids Sandbox OCSP flakiness
        env,
        BUNDLE_ID,
        APP_APPLE_ID,
      );
      return await verifier.verifyAndDecodeTransaction(jws);
    } catch (e) {
      console.error(`verify failed env=${env}:`, (e as Error)?.message ?? e);
    }
  }
  return null;
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

  // 1. Entitlement: verify the StoreKit 2 signed transaction.
  const tx = await verifyTransaction(jws);
  if (!tx) {
    console.error("entitlement: verify returned null (JWS not Apple-verifiable)");
    return json(403, { error: "verify_failed" });
  }
  console.log("entitlement: verified productId=", tx.productId, "env ok");
  if (!PRODUCT_IDS.has(tx.productId)) {
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
