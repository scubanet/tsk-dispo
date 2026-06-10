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
- [x] 1. `supabase/functions/speech/index.ts` (Verify-Code von `translate` übernommen; `translate` selbst unangetastet)
- [x] 2. AtollSpeech: Protokolle + `ProxySpeechClient` + `ElevenLabsSynthesizer`-Umbau
- [x] 3. App: Config/DeviceID/SpeechService/SynthesisService/RootView
- [x] 4. Tests: ProxySpeechClient (MockURLProtocol: Header, Pfade, Fehler-Mapping), bestehende Suiten anpassen
- [x] 5. Build + Tests grün (48/48); `grep -r sk_` leer (2026-06-10)
- [x] 6. Deploy `speech` v1 + Secret gesetzt; Smoke verifiziert: stt ohne device→400, stt+WAV→200 (Scribe end-to-end), tts ohne jws→403, fake jws→403 (2026-06-10)
- [x] 7. Commits `1e0239a` + `eebd646`
- [ ] 8. **Dominik: ElevenLabs-Key rotieren** (alter Key in Git-History 542d7dd) → neuen Key als Secret setzen (gleicher Einzeiler) — danach ist der alte wertlos
- [ ] 9. Real-Device-Test: 1 Satz Free (Apple-Stimme, Proxy-STT) + 1 Satz Pro (ElevenLabs-Stimme via Proxy)
