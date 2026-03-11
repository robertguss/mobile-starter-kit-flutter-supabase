# Security

## Secret Boundaries

### Safe to embed in the Flutter app

These values are designed to ship in client builds:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_REDIRECT_URL`
- `POWERSYNC_URL`
- `SENTRY_DSN`
- `POSTHOG_API_KEY`
- `POSTHOG_HOST`
- `REVENUECAT_APPLE_PUBLIC_SDK_KEY`
- `REVENUECAT_GOOGLE_PUBLIC_SDK_KEY`
- `ONESIGNAL_APP_ID`

The app treats these as public configuration, not credentials.

### Never embed in the Flutter app

These values must remain server-side only:

- `SUPABASE_SERVICE_ROLE_KEY`
- `REVENUECAT_WEBHOOK_AUTH_KEY`
- `ONESIGNAL_TRIGGER_AUTH_KEY`
- `ONESIGNAL_APP_API_KEY`
- App Store Connect API keys
- Android signing keys
- Fastlane Match credentials

`SUPABASE_SERVICE_ROLE_KEY` is only used inside Supabase Edge Functions through
[supabase/functions/_shared/supabase-client.ts](/Users/robertguss/.config/superpowers/worktrees/flutter-supabase-starter-kit/codex-flutter-supabase-starter-kit/supabase/functions/_shared/supabase-client.ts).

## Secret Storage

### Supabase Edge Functions

Store backend-only values with `supabase secrets set` before deploying:

```bash
supabase secrets set \
  SUPABASE_URL=... \
  SUPABASE_SERVICE_ROLE_KEY=... \
  REVENUECAT_WEBHOOK_AUTH_KEY=... \
  ONESIGNAL_TRIGGER_AUTH_KEY=... \
  ONESIGNAL_APP_ID=... \
  ONESIGNAL_APP_API_KEY=...
```

### GitHub Actions

Store production and signing values only in GitHub Actions secrets and protected
environments. Do not commit JSON configs with real values. The workflows expect
the secrets documented in
[docs/DEPLOYMENT.md](/Users/robertguss/.config/superpowers/worktrees/flutter-supabase-starter-kit/codex-flutter-supabase-starter-kit/docs/DEPLOYMENT.md).

### CI Secret Scanning

The PR workflow runs `gitleaks` on every pull request. Treat a secret-scan
failure as a release blocker and rotate any leaked credential before merging.

## Mobile Hardening

### Auth token storage

Supabase sessions are persisted through
[lib/core/database/secure_auth_storage.dart](/Users/robertguss/.config/superpowers/worktrees/flutter-supabase-starter-kit/codex-flutter-supabase-starter-kit/lib/core/database/secure_auth_storage.dart),
which uses `flutter_secure_storage`. Do not switch back to plaintext local
storage.

### Code obfuscation

Release workflows already build with `--obfuscate --split-debug-info=...`.
Keep those flags enabled for Play Store and App Store releases.

### Local SQLite protection

PowerSync stores a local SQLite database for offline-first behavior. Treat that
database as device-local, not encrypted-at-rest application storage. For
high-sensitivity apps, document the data model, minimize cached PII, and layer
platform protections such as full-disk encryption and device compliance checks.

### Certificate pinning

This starter does not enable certificate pinning by default because it adds
operational risk for a template repo. Production apps with higher threat models
should add pinning for their API surface and define a rollover process before
shipping.

### Root and jailbreak detection

This starter does not block rooted or jailbroken devices by default. Production
apps handling regulated or high-value data should add device-integrity checks
and decide whether to warn, degrade, or block usage.

### Screenshot and screen-recording protection

This starter does not globally disable screenshots. Apps with sensitive account
or billing screens should add platform-specific protections for those screens
and confirm that the UX still supports password managers and accessibility.

### Deep link validation

Only register the exact Supabase auth callback scheme and host you expect. Do
not accept arbitrary redirect targets from user-controlled input.

## Edge Function Hardening

### Current protections

The shipped functions already implement the core server-side controls:

- Constant-time auth header verification
- Request payload validation
- Generic error responses without stack traces
- Service-role access only in the RevenueCat webhook
- Audit logging and idempotency for RevenueCat webhook events

See:

- [supabase/functions/revenuecat-webhook/handler.ts](/Users/robertguss/.config/superpowers/worktrees/flutter-supabase-starter-kit/codex-flutter-supabase-starter-kit/supabase/functions/revenuecat-webhook/handler.ts)
- [supabase/functions/onesignal-trigger/handler.ts](/Users/robertguss/.config/superpowers/worktrees/flutter-supabase-starter-kit/codex-flutter-supabase-starter-kit/supabase/functions/onesignal-trigger/handler.ts)

### Rate limiting

Supabase Edge Functions do not provide app-level abuse protection by default.
For production, front these endpoints with an API gateway, WAF, or equivalent
rate-limiting control if they are exposed beyond trusted backend callers.

### CORS

The current functions are intended for server-to-server use and do not return
permissive CORS headers. If you expose a function to browser clients later, add
an explicit allowlist rather than `*`.

## Observability

### Sentry PII

The default Sentry config sets `sendDefaultPii = false` and
`attachScreenshot = false` in
[lib/core/observability/sentry_config.dart](/Users/robertguss/.config/superpowers/worktrees/flutter-supabase-starter-kit/codex-flutter-supabase-starter-kit/lib/core/observability/sentry_config.dart).
Re-review those settings before enabling user identifiers or replay features.

### Audit logging

RevenueCat webhook processing is recorded in `webhook_audit_log`. Extend the
same pattern for other irreversible or billing-affecting backend operations.

### Alerting

Configure production alerts for:

- auth failure spikes
- webhook 4xx and 5xx increases
- push trigger failures
- unusual sign-out or session-reset rates
- startup regressions in Sentry performance traces
