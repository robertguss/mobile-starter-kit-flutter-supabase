# Flutter Supabase Starter Kit

Offline-first Flutter starter kit built with Supabase, PowerSync, Riverpod,
GoRouter, RevenueCat, OneSignal, Sentry, PostHog, slang, and flutter_gen.

## What’s Included

- Email OTP authentication with Supabase Auth
- Offline-first local data access with PowerSync and SQLite
- Notes reference feature showing the intended domain/data/presentation pattern
- RevenueCat paywall flow and subscription state sync
- OneSignal notification permission flow and server-side trigger function
- Supabase Edge Functions for RevenueCat webhooks and OneSignal delivery
- Riverpod generator, GoRouter, Material 3 theming, slang i18n, and generated assets

## Prerequisites

- Flutter 3.35+
- Dart 3.11+
- Deno 2+
- Supabase CLI
- Xcode 15+ for iOS builds
- Android Studio or Android SDK with Java 17

External service accounts required:

- Supabase
- PowerSync
- RevenueCat
- OneSignal
- Sentry
- PostHog

## Quick Start

1. Install dependencies.

```bash
flutter pub get
```

2. Copy the example environment file and create a local runtime config file.

```bash
cp .env.example .env
cp config/config_dev.json config/config_local.json
```

3. Fill in the required keys in `.env` and `config/config_local.json`.

4. Start local Supabase services and apply the migrations.

```bash
make supabase-start
make supabase-reset
```

5. Apply the tracked PowerSync Sync Streams config from
   `powersync/sync_rules.yaml` in your PowerSync project.

6. Generate code and translations.

```bash
make codegen
```

7. Run the app.

```bash
flutter run --dart-define-from-file=config/config_local.json
```

## Configuration

The Flutter app expects these runtime values:

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

`config/config_dev.json` shows the expected JSON shape for local development.

Edge Functions expect these secrets in the Supabase environment:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `REVENUECAT_WEBHOOK_AUTH_KEY`
- `ONESIGNAL_TRIGGER_AUTH_KEY`
- `ONESIGNAL_APP_ID`
- `ONESIGNAL_APP_API_KEY`

PowerSync Sync Streams are tracked in `powersync/sync_rules.yaml`. Keep this
file aligned with Supabase RLS policies whenever you add a synced table.

## Common Commands

```bash
make setup
make codegen
make analyze
make test
make edge-test
make supabase-start
make supabase-reset
```

## Architecture

Feature code lives under `lib/features/<feature>/` and follows a strict split:

- `domain/` contains entities and abstract repository contracts
- `data/` contains PowerSync, Supabase, RevenueCat, or OneSignal implementations
- `presentation/` contains Riverpod controllers and widgets

The current reference features are:

- `auth` for OTP-based authentication
- `notes` for offline-first CRUD
- `subscription` for RevenueCat-backed purchase state
- `notifications` for OneSignal permission flow

See [docs/ARCHITECTURE.md](/Users/robertguss/.config/superpowers/worktrees/flutter-supabase-starter-kit/codex-flutter-supabase-starter-kit/docs/ARCHITECTURE.md) for the full structure and data flow.

## Adding a Feature

1. Create `lib/features/<feature>/domain/` with the entity and repository contract.
2. Add a mock in `test/features/<feature>/domain/`.
3. Write controller and screen tests first.
4. Implement the concrete repository in `data/`.
5. Build the Riverpod controller and UI in `presentation/`.
6. Wire the repository in `main.dart` or the relevant provider override.

Use the `notes` feature as the reference implementation.

## Verification

Run these before pushing:

```bash
make analyze
make test
make edge-test
```
