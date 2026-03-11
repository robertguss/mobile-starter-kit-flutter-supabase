# Deployment

## GitHub Secrets

The current CI/CD scaffolding uses 14 GitHub Secrets across the release and
backend workflows:

### Shared app config

- `CONFIG_PROD_JSON`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`

### Android release

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

### iOS release

- `MATCH_PASSWORD`
- `MATCH_GIT_URL`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`

## Supabase Edge Function Secrets

Set these in Supabase before deploying functions:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `REVENUECAT_WEBHOOK_AUTH_KEY`
- `ONESIGNAL_TRIGGER_AUTH_KEY`
- `ONESIGNAL_APP_ID`
- `ONESIGNAL_APP_API_KEY`

Example:

```bash
supabase secrets set \
  REVENUECAT_WEBHOOK_AUTH_KEY=... \
  ONESIGNAL_TRIGGER_AUTH_KEY=... \
  ONESIGNAL_APP_ID=... \
  ONESIGNAL_APP_API_KEY=...
```

See
[docs/SECURITY.md](/Users/robertguss/.config/superpowers/worktrees/flutter-supabase-starter-kit/codex-flutter-supabase-starter-kit/docs/SECURITY.md)
for the full embedded-vs-server-only key split and mobile hardening guidance.

## PowerSync Sync Streams

Apply `powersync/sync_rules.yaml` to the target PowerSync project before
shipping. The rules mirror the current Supabase RLS scope for `notes` and
`subscriptions`, so update this file in the same change whenever synced tables
or access rules change.

## Rollback

### Android

- Halt or roll back the staged rollout in Google Play Console.
- Promote the previous production release if the bad rollout has already hit a
  measurable audience.
- Re-run `build-android.yml` from the last known good tag if a rebuilt bundle is
  required.

### iOS

- Stop the phased release in App Store Connect if it is still in progress.
- Promote the previous TestFlight build for internal testers, then ship a
  replacement build. App Store production rollback still requires a new
  submission.

### Supabase migrations

- Create a corrective migration with `supabase migration new revert_<change>`.
- Validate it locally with `make supabase-reset`.
- Apply it with `supabase db push` after the project is linked.

### Edge Functions

- Check out the last known good commit and redeploy the affected function:

```bash
supabase link --project-ref "$SUPABASE_PROJECT_REF"
supabase functions deploy revenuecat-webhook
supabase functions deploy onesignal-trigger
```

### PowerSync and backend config

- Reapply `powersync/sync_rules.yaml` from the last known good commit in the
  PowerSync dashboard.
- Re-run a notes sync smoke test before reopening rollout.

## Monitoring

Before and after a release, watch:

- Sentry startup traces for regression against the startup target
- RevenueCat webhook failures and duplicate-event handling
- OneSignal trigger 5xx responses
- auth failure spikes and unusual sign-out/reset rates

Treat secret-scan failures, repeated webhook authorization errors, and rollout
signing/config mismatches as no-go signals.
