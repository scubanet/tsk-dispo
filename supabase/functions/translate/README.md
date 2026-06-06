# translate (AtollTalk Pro proxy)

Holds the Claude key server-side. Verifies the caller's StoreKit 2 signed
transaction (Apple `app-store-server-library`, x5c chain → Apple root CAs),
enforces a daily fair-use cap, then calls Claude.

## Secrets

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
supabase secrets set ATOLLTALK_BUNDLE_ID=swiss.atoll.talk
supabase secrets set APP_APPLE_ID=<numeric app id>   # required for Production verify
```

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
- `403 not_entitled|revoked|expired`, `429 rate_limited`, `400/500/502` otherwise.

## Notes / review before launch

- Sandbox vs Production: the verifier tries Production then Sandbox. TestFlight
  builds produce Sandbox transactions.
- `DAILY_LIMIT` (2000) — tune to real cost budget.
- Apple root CAs are fetched from apple.com at cold start; consider vendoring
  the `.cer` files if you want zero external fetch at runtime.
