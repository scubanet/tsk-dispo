// AtollTalk speech proxy (ElevenLabs Scribe STT + TTS).
//
// Keeps ELEVENLABS_API_KEY server-side. Routes:
//   POST /speech/stt            — both tiers. Header x-atoll-device (anonymous
//                                 install UUID) required; x-atoll-jws optional
//                                 (verified Pro gets the higher daily cap).
//                                 Body: raw WAV bytes (content-type audio/wav).
//                                 Response: Scribe JSON passthrough.
//   POST /speech/tts/<voiceID>  — Pro only (StoreKit 2 JWS verified like the
//                                 translate function). Body { text, model_id? }.
//                                 Response: audio/mpeg bytes.
//
// Rate limits via public.atolltalk_bump_usage (text keys, one row per key+day):
//   stt:dev:<uuid> 300/day · stt:sub:<originalTransactionId> 2000/day ·
//   tts:sub:<originalTransactionId> 2000/day
//
// Required secrets (supabase secrets set ...):
//   ELEVENLABS_API_KEY  - ElevenLabs key (never shipped in the app)
//   ATOLLTALK_BUNDLE_ID - e.g. swiss.atoll.talk        (shared with translate)
//   APP_APPLE_ID        - numeric App Store app id      (shared with translate)
// Provided automatically: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// Deploy with JWT off (we do our own auth):
//   supabase functions deploy speech --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  SignedDataVerifier,
  Environment,
} from "https://esm.sh/@apple/app-store-server-library@1.4.0";

const ELEVENLABS_API_KEY = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
const BUNDLE_ID = Deno.env.get("ATOLLTALK_BUNDLE_ID") ?? "swiss.atoll.talk";
const APP_APPLE_ID = Number(Deno.env.get("APP_APPLE_ID") ?? "0") || undefined;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const PRODUCT_IDS = new Set([
  "swiss.atoll.talk.pro.monthly",
  "swiss.atoll.talk.pro.yearly",
  "swiss.atoll.talk.pro.lifetime",
]);
const STT_DEVICE_DAILY = 300;   // Free fair-use per install
const STT_PRO_DAILY = 2000;
const TTS_PRO_DAILY = 2000;
const MAX_WAV_BYTES = 4 * 1024 * 1024;  // ~2 min of 16 kHz mono Int16
const MAX_TTS_CHARS = 2000;
const SCRIBE_MODEL = "scribe_v1";
const TTS_MODEL = "eleven_multilingual_v2";
const DEVICE_RE = /^[0-9a-fA-F-]{36}$/;
const VOICE_RE = /^[A-Za-z0-9]{8,40}$/;

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

// Returns the original transaction id when the JWS proves an active Pro
// entitlement; null otherwise.
async function proAccount(jws: string): Promise<string | null> {
  const tx = await verifyTransaction(jws);
  if (!tx) return null;
  if (!PRODUCT_IDS.has(tx.productId ?? "")) return null;
  if (tx.revocationDate) return null;
  if (tx.expiresDate && tx.expiresDate < Date.now()) return null;
  return tx.originalTransactionId ?? null;
}

// Atomic daily counter; true when the call is within `limit`.
async function withinLimit(key: string, limit: number): Promise<boolean | null> {
  const today = new Date().toISOString().slice(0, 10);
  const supa = createClient(SUPABASE_URL, SERVICE_ROLE);
  const { data: count, error } = await supa.rpc("atolltalk_bump_usage", {
    p_account: key,
    p_day: today,
  });
  if (error) {
    console.error("usage rpc failed:", error.message);
    return null;
  }
  return typeof count === "number" ? count <= limit : null;
}

async function handleSTT(req: Request): Promise<Response> {
  const device = req.headers.get("x-atoll-device") ?? "";
  if (!DEVICE_RE.test(device)) return json(400, { error: "missing_device" });

  // Pro JWS (optional) upgrades the daily cap.
  let key = `stt:dev:${device.toLowerCase()}`;
  let limit = STT_DEVICE_DAILY;
  const jws = req.headers.get("x-atoll-jws");
  if (jws) {
    const account = await proAccount(jws);
    if (account) {
      key = `stt:sub:${account}`;
      limit = STT_PRO_DAILY;
    }
  }

  const audio = new Uint8Array(await req.arrayBuffer());
  if (audio.byteLength === 0) return json(400, { error: "empty_audio" });
  if (audio.byteLength > MAX_WAV_BYTES) return json(413, { error: "audio_too_large" });

  const ok = await withinLimit(key, limit);
  if (ok === null) return json(500, { error: "usage_failed" });
  if (!ok) return json(429, { error: "rate_limited" });

  const form = new FormData();
  form.set("model_id", SCRIBE_MODEL);
  form.set("tag_audio_events", "false");
  form.set("timestamps_granularity", "none");
  form.set("diarize", "false");
  form.set("file", new Blob([audio], { type: "audio/wav" }), "audio.wav");

  const res = await fetch("https://api.elevenlabs.io/v1/speech-to-text", {
    method: "POST",
    headers: { "xi-api-key": ELEVENLABS_API_KEY },
    body: form,
  });
  if (!res.ok) {
    const detail = await res.text();
    console.error("scribe error", res.status, detail.slice(0, 300));
    return json(res.status === 429 ? 429 : 502, { error: "stt_failed" });
  }
  return new Response(await res.arrayBuffer(), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

async function handleTTS(req: Request, voiceID: string): Promise<Response> {
  if (!VOICE_RE.test(voiceID)) return json(400, { error: "bad_voice" });

  const jws = req.headers.get("x-atoll-jws") ?? "";
  if (!jws) return json(403, { error: "pro_required" });
  const account = await proAccount(jws);
  if (!account) return json(403, { error: "verify_failed" });

  let body: { text?: string; model_id?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_json" });
  }
  const text = (body.text ?? "").trim();
  if (!text) return json(400, { error: "missing_text" });
  if (text.length > MAX_TTS_CHARS) return json(413, { error: "text_too_long" });

  const ok = await withinLimit(`tts:sub:${account}`, TTS_PRO_DAILY);
  if (ok === null) return json(500, { error: "usage_failed" });
  if (!ok) return json(429, { error: "rate_limited" });

  const res = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceID}`,
    {
      method: "POST",
      headers: {
        "xi-api-key": ELEVENLABS_API_KEY,
        "content-type": "application/json",
        accept: "audio/mpeg",
      },
      body: JSON.stringify({
        text,
        model_id: TTS_MODEL, // fixed allowlist of one — ignore client overrides
        voice_settings: { stability: 0.5, similarity_boost: 0.75 },
      }),
    },
  );
  if (!res.ok) {
    const detail = await res.text();
    console.error("tts error", res.status, detail.slice(0, 300));
    return json(res.status === 429 ? 429 : 502, { error: "tts_failed" });
  }
  return new Response(await res.arrayBuffer(), {
    status: 200,
    headers: { "content-type": "audio/mpeg" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (!ELEVENLABS_API_KEY) return json(500, { error: "server_misconfigured" });

  // Path after the function name: /speech/stt | /speech/tts/<voiceID>
  const parts = new URL(req.url).pathname.split("/").filter(Boolean);
  const i = parts.indexOf("speech");
  const route = parts[i + 1] ?? "";
  if (route === "stt") return handleSTT(req);
  if (route === "tts" && parts[i + 2]) return handleTTS(req, parts[i + 2]);
  return json(404, { error: "not_found" });
});
