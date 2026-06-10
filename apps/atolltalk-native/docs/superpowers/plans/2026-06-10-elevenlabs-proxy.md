# AtollTalk ElevenLabs-Proxy — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: **superpowers:executing-plans**. Checkbox-Syntax (`- [ ]`).

**Goal:** Der ElevenLabs-Key verschwindet aus dem App-Binary. STT (Scribe, beide Tiers) und TTS (Pro) laufen über eine Supabase Edge Function `speech`; der Key liegt serverseitig. Danach **Key bei ElevenLabs rotieren** (der alte steht in der Git-History, Commit 542d7dd).

**Entscheide (Dominik, 2026-06-10):**
- Interim-Key war nur für TestFlight ok → Proxy jetzt, vor Public Launch.
- Free-Tier-Auth: **anonyme Install-UUID + Server-Rate-Limit** (kein DeviceCheck/App-Attest in v1; Upgrade-Pfad offenhalten).

**Architecture:**
- **Eine** Function `speech` mit Subrouten (eigene Functions wären 2 Deploys für denselben Verify-Code):
  - `POST /speech/stt` — Header `x-atoll-device: <uuid>` (immer), `x-atoll-jws: <jws>` (nur Pro). Body = roher WAV (`content-type: audio/wav`). Function baut das ElevenLabs-Multipart serverseitig, antwortet mit dem Scribe-JSON unverändert (`text`, `language_code`, `language_probability`).
  - `POST /speech/tts/<voiceID>` — **nur Pro** (JWS-Verify wie `translate`: Apple-Root-Anker, Product-Allowlist, Revocation/Expiry). Body `{ text, model_id? }`, Antwort `audio/mpeg`-Bytes.
- **Rate-Limits** über bestehende RPC `atolltalk_bump_usage` (text-Keys, keine Migration): `stt:dev:<uuid>` 300/Tag · `stt:sub:<tid>` 2000/Tag · `tts:sub:<tid>` 2000/Tag. Guards: WAV ≤ 4 MB, TTS-Text ≤ 2000 Zeichen, voiceID `^[A-Za-z0-9]{8,40}$`.
- **Client (AtollSpeech):** Protokolle `Transcribing` + `Synthesizing` (synthesize→Data); `ElevenLabsClient` konformiert (Direkt-Modus für Dev/Tests), neu `ProxySpeechClient` (baseURL, device-UUID, optionale async JWS-Closure). `ElevenLabsSynthesizer` nimmt `any Synthesizing`.
- **App:** `Config.elevenLabsAPIKey` ersatzlos raus; neu `Config.speechProxyURL`. Neu `DeviceID.current` (UserDefaults-persistierte UUID). `RootView.rebuild()` injiziert `ProxySpeechClient` in `SpeechService`/`SynthesisService` (Pro: mit JWS-Closure).
- **Secrets:** `ELEVENLABS_API_KEY` neu setzen (`supabase secrets set`); `ATOLLTALK_BUNDLE_ID`/`APP_APPLE_ID` existieren von `translate`.

## Tasks
- [ ] 1. `supabase/functions/speech/index.ts` (Verify-Code von `translate` übernommen; `translate` selbst unangetastet)
- [ ] 2. AtollSpeech: Protokolle + `ProxySpeechClient` + `ElevenLabsSynthesizer`-Umbau
- [ ] 3. App: Config/DeviceID/SpeechService/SynthesisService/RootView
- [ ] 4. Tests: ProxySpeechClient (MockURLProtocol: Header, Pfade, Fehler-Mapping), bestehende Suiten anpassen
- [ ] 5. Build + 42+-Tests grün; `grep -r sk_ AtollTalk/` leer
- [ ] 6. Deploy `speech` (`--no-verify-jwt`), Secret setzen, Smoke-Test (curl: stt ohne device → 400, tts ohne jws → 403)
- [ ] 7. Commit(s); **Dominik: ElevenLabs-Key rotieren** → neuer Key nur als Supabase-Secret
