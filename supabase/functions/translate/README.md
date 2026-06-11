# translate (AtollTalk Pro proxy)

Holds the Claude key server-side. Verifies the caller's StoreKit 2 signed
transaction (JWS ES256 signature via `jose`, x5c chain anchored to Apple root
CAs via `@peculiar/x509`), enforces a daily fair-use cap, then calls Claude.

> **Why not `app-store-server-library`?** It verifies the cert chain with Node's
> `crypto.X509Certificate.prototype.verify()`, which the Supabase Edge (Deno)
> runtime does not implement (`ERR_NOT_IMPLEMENTED`) — every JWS failed. The
> WebCrypto-based verification here works in Deno.

## Secrets

```bash
# Set without a trailing newline — printf, not echo:
printf 'sk-ant-...' | supabase secrets set ANTHROPIC_API_KEY=/dev/stdin
supabase secrets set ATOLLTALK_BUNDLE_ID=swiss.atoll.talk
```

`APP_APPLE_ID` is no longer needed (the old library required it for Production
verification; the Deno-native verifier anchors the chain itself).

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically.

## Deploy

```bash
supabase functions deploy translate --no-verify-jwt   # we do our own (StoreKit) auth
```

Apply the migration first (`atolltalk_usage` table + `atolltalk_bump_usage`).

## Request / response

`POST` JSON: `{ text, source, target, context, glossary, model, jws }`
- `jws` = `VerificationResult.jwsRepresentation` of the active Pro entitlement.
- `200 { text }` on success.
- `403 verify_failed|wrong_product|revoked|expired`, `429 rate_limited`, `400/500/502` otherwise.

## Notes / review before launch

- Sandbox vs Production: the verifier accepts both — it anchors the x5c chain to
  Apple's root CAs and checks the JWS signature regardless of `environment`.
  TestFlight builds produce Sandbox transactions; the App Store produces
  Production ones. Both pass.
- `DAILY_LIMIT` (2000) — tune to real cost budget.
- Apple root CAs are fetched from apple.com at cold start; consider vendoring
  the `.cer` files if you want zero external fetch at runtime.
