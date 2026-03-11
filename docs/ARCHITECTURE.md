# Architecture

## Goals

- Keep Flutter feature code isolated and predictable
- Default all user data access to offline-first PowerSync reads and writes
- Reserve direct Supabase access for auth, storage, and Edge Functions
- Keep third-party SDK coordination in startup and session orchestration code

## Flutter Structure

The app follows a strict feature-first layout:

```text
lib/
  core/
    database/
    env/
    observability/
    providers/
    router/
    session/
    theme/
    widgets/
  features/
    auth/
      domain/
      data/
      presentation/
    notes/
      domain/
      data/
      presentation/
    subscription/
      domain/
      data/
      presentation/
    notifications/
      domain/
      data/
      presentation/
```

## Startup Flow

`lib/main.dart` coordinates app boot:

1. Initialize Flutter bindings and Sentry
2. Initialize Supabase
3. Open the PowerSync database
4. Build the session manager
5. Override repository providers in `ProviderScope`
6. Render the app
7. Initialize non-critical SDKs after first frame:
   PostHog, RevenueCat, and OneSignal

## Data Flow

### Auth

- `SupabaseAuthRepository` handles OTP send, verify, auth stream, and sign-out
- `AuthController` projects auth state into Riverpod
- `AuthRouteStateNotifier` drives router redirects

### Offline Notes

- `PowerSyncNoteRepository` uses raw SQL against the local PowerSync database
- `NotesController` watches local rows and mutates the cached list
- `NoteDetailScreen` debounces edits and persists through the repository

### Subscription

- `RevenueCatSubscriptionRepository` loads offerings and customer info
- `SubscriptionController` prewarms at app startup and listens for RevenueCat updates
- `PaywallScreen` renders available packages and restore actions

### Notifications

- `OneSignalNotificationRepository` reads and requests notification permission
- `NotificationSettingsController` keeps permission state in Riverpod
- `NotificationSettingsScreen` requests permission only on the settings screen

## Session Lifecycle

`core/session/session_manager.dart` is responsible for cross-SDK user lifecycle:

- On sign-in:
  - `Purchases.logIn(userId)`
  - `OneSignal.login(userId)`
  - `PowerSync.connect(...)`
- On sign-out:
  - `PowerSync.clear(...)`
  - `Purchases.logOut()`
  - `OneSignal.logout()`
  - `Supabase.auth.signOut()`

This prevents user data bleed across sessions.

## Edge Functions

The shared function infrastructure lives in `supabase/functions/_shared/`.

- `supabase-client.ts` builds a service-role Supabase client
- `responses.ts` provides consistent JSON response helpers
- `types.ts` contains typed RevenueCat payload contracts

Implemented functions:

- `revenuecat-webhook`
  - Verifies the incoming `Authorization` header using constant-time comparison
  - Validates the webhook payload
  - Rejects anonymous or invalid user IDs
  - Upserts subscription state
  - Tracks processing in `webhook_audit_log`
- `onesignal-trigger`
  - Verifies an internal auth header
  - Validates notification payloads
  - Sends push notifications through the OneSignal REST API

## Testing Strategy

- Flutter unit and widget tests live under `test/`
- Feature controllers are tested against mocks generated with `mocktail`
- Golden tests cover the notes widgets
- Deno tests cover Edge Function handlers without requiring live infrastructure

## Current Gaps

- PowerSync Sync Streams are tracked in `powersync/sync_rules.yaml`, but still
  require ongoing verification in each real PowerSync project
- Acceptance checks that depend on live third-party accounts remain manual:
  OTP auth, purchases, webhook delivery, and push delivery
