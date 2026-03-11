# Deployment

## GitHub Secrets

The current CI/CD scaffolding expects these GitHub Secrets:

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

### Supabase Edge Functions

- `REVENUECAT_WEBHOOK_AUTH_KEY`
- `ONESIGNAL_TRIGGER_AUTH_KEY`
- `ONESIGNAL_APP_ID`
- `ONESIGNAL_APP_API_KEY`

## Supabase Edge Function Secrets

Set these in Supabase before deploying functions:

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

## Rollback

### Android

- Halt or roll back the staged rollout in Google Play Console.
- Re-run the Android workflow from the last good tag if a rebuild is needed.

### iOS

- Promote the previous TestFlight build or submit a replacement build.
- App Store production rollback requires a new submission.

### Supabase migrations

- Create and apply an explicit corrective migration.
- Verify against a local reset first with `make supabase-reset`.

### Edge Functions

- Check out the last good commit and redeploy:

```bash
supabase functions deploy revenuecat-webhook
supabase functions deploy onesignal-trigger
```

### PowerSync and backend config

- Reapply the previous sync rules or project configuration from the last known good export.
