---
title: "feat: Flutter & Supabase Production Starter Kit"
type: feat
status: active
date: 2026-03-10
origin: docs/brainstorms/2026-03-10-flutter-supabase-starter-kit-brainstorm.md
---

# feat: Flutter & Supabase Production Starter Kit

## Enhancement Summary

**Deepened on:** 2026-03-10 **Sections enhanced:** All 7 phases + architecture +
security + CI/CD **Review agents used:** security-sentinel, performance-oracle,
architecture-strategist, code-simplicity-reviewer, data-integrity-guardian,
pattern-recognition-specialist, kieran-typescript-reviewer,
deployment-verification-agent, security-scanning skill, cicd-automation skill,
database-design skill

### Key Improvements

1. **Architecture:** Added `core/providers/` layer for shared Riverpod
   providers, `core/session/session_manager.dart` (Mediator pattern) to decouple
   sign-out from auth repository, `core/widgets/async_value_widget.dart` for
   shared error/loading UI, and explicit dependency direction rules
2. **Security:** 7 STRIDE-based security sections (SEC-1 through SEC-7) covering
   RLS hardening, secure JWT storage via `flutter_secure_storage`, webhook
   constant-time verification, secret management, mobile security, Edge Function
   hardening, and observability
3. **Performance:** Defer non-critical SDK init (PostHog, RevenueCat, OneSignal)
   to post-first-frame to hit <3s launch target; batch-limit PowerSync uploads
   to 100 ops; paginate notes list (limit: 50)
4. **Data integrity:** 14 findings — `updated_at` trigger, per-operation RLS
   with `FORCE RLS`, FK indexes on `user_id`, `NOT NULL` constraints,
   `ON DELETE CASCADE`, composite indexes
5. **CI/CD:** Secret generation from GitHub Secrets in CI, Supabase Edge
   Function deployment workflow, build caching (saves 10-14 min), rollback
   procedures, `dart format` check
6. **TypeScript Edge Functions:** Typed webhook payloads with discriminated
   unions, constant-time auth verification, `handler.ts` extraction for
   testability, `_shared/` directory for common code
7. **Mobile UX:** Splash screen during boot, connectivity provider, golden tests
   for design system widgets, pull-to-refresh, `ListView.builder` performance,
   integration test for offline→online sync, startup performance measurement

### Scope Discussion (from simplicity review)

The simplicity reviewer recommends deferring RevenueCat, OneSignal, and PostHog
to reduce scope from 7 phases to 5 and service accounts from 8 to 5. **This is a
valid option** — the Notes feature alone demonstrates the full architecture
pattern. The plan as written includes everything; implementers can choose to
defer Phase 6 integrations.

### Review Documents

All detailed review findings are in `docs/reviews/`:

- `2026-03-10-security-review.md` — 21 findings (3 critical, 7 high)
- `2026-03-10-performance-review.md` — 9 findings (2 P0)
- `2026-03-10-architecture-review.md` — 9 findings (1 critical, 2 high)
- `2026-03-10-plan-simplicity-review.md` — scope reduction analysis
- `2026-03-10-data-integrity-review.md` — 14 findings (5 critical)
- `2026-03-10-edge-functions-typescript-review.md` — 10 findings (3 critical)
- `2026-03-10-cicd-deployment-review.md` — NO-GO verdict, 5 critical gaps
- `docs/analysis/2026-03-10-pattern-consistency-review.md` — 16 findings
- `docs/plans/2026-03-10-cicd-recommendations.md` — Full CI/CD implementation
  guide
- `docs/plans/2026-03-10-database-design-recommendations.md` — Complete SQL with
  indexes

## Overview

Build a production-ready, full-stack Flutter + Supabase starter kit distributed
as a GitHub template repository. It serves both human developers (solo/indie)
and AI coding agents equally, shipping as a full monolith with every integration
wired and working out of the box.

Users click "Use this template" on GitHub and get: auth (Email OTP),
offline-first data sync (PowerSync), monetization (RevenueCat), push
notifications (OneSignal), observability (Sentry + PostHog), i18n, asset
management, and CI/CD — all with full TDD coverage.

(see brainstorm:
docs/brainstorms/2026-03-10-flutter-supabase-starter-kit-brainstorm.md)

## Problem Statement

Starting a production Flutter app requires wiring together 10-15 packages,
configuring platform-specific settings, establishing architecture patterns, and
setting up CI/CD. This takes days or weeks and is error-prone. Existing starter
kits are either too minimal (just auth) or poorly architected (no offline
support, no TDD, no conventions for AI agents).

This starter kit eliminates that friction by providing a fully wired,
well-tested, conventioned template that both humans and AI agents can extend
predictably.

## Proposed Solution

A 6-phase sequential build producing a GitHub template repository with
feature-first architecture, strict TDD, and offline-first data layer. Includes a
sample "Notes" feature demonstrating the full architecture pattern end-to-end.

## Technical Approach

### Architecture

**Feature-First Directory Structure:**

```
lib/
├── main.dart                    # Sentry wraps → Supabase → PowerSync → runApp
├── core/
│   ├── router/
│   │   └── app_router.dart      # Centralized GoRouter with auth redirect
│   ├── theme/
│   │   ├── app_theme.dart       # Material 3 ThemeData (light + dark)
│   │   ├── app_colors.dart      # Centralized color palette
│   │   └── app_typography.dart  # Typography scale
│   ├── env/
│   │   └── env.dart             # --dart-define-from-file loader
│   ├── database/
│   │   ├── supabase_client.dart # Supabase singleton
│   │   ├── powersync_client.dart# PowerSync database singleton
│   │   ├── powersync_schema.dart# Unified schema (crosses feature boundaries)
│   │   └── powersync_connector.dart # fetchCredentials + uploadData
│   ├── providers/               # [ADDED] Shared Riverpod providers
│   │   ├── database_providers.dart  # PowerSync + Supabase provider overrides
│   │   └── connectivity_provider.dart # Network status stream
│   ├── session/                 # [ADDED] Cross-feature session management
│   │   └── session_manager.dart # Mediator: sign-out orchestration across SDKs
│   ├── observability/
│   │   ├── sentry_config.dart   # Sentry initialization
│   │   ├── posthog_config.dart  # PostHog initialization
│   │   └── provider_observer.dart # Riverpod ProviderObserver → Sentry
│   ├── widgets/                 # [ADDED] Shared presentation patterns
│   │   ├── async_value_widget.dart  # Reusable AsyncValue → data/loading/error
│   │   └── error_screen.dart    # Full-screen error with retry
│   └── constants/
│       └── app_constants.dart   # App-wide constants
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   ├── auth_repository.dart      # Abstract interface
│   │   │   └── user_model.dart           # User entity
│   │   ├── data/
│   │   │   └── supabase_auth_repository.dart # Supabase Auth SDK impl
│   │   └── presentation/
│   │       ├── auth_controller.dart      # @riverpod annotated (generates .g.dart)
│   │       ├── login_screen.dart         # OTP request screen
│   │       └── otp_verify_screen.dart    # OTP verification screen
│   ├── notes/                            # SAMPLE FEATURE (demonstrates architecture)
│   │   ├── domain/
│   │   │   ├── note_repository.dart      # Abstract interface
│   │   │   └── note_model.dart           # Note entity
│   │   ├── data/
│   │   │   └── powersync_note_repository.dart # PowerSync CRUD impl
│   │   └── presentation/
│   │       ├── notes_controller.dart     # @riverpod annotated (generates .g.dart)
│   │       ├── notes_list_screen.dart    # List with offline indicator
│   │       ├── note_detail_screen.dart   # View/edit single note
│   │       └── widgets/
│   │           ├── note_card.dart
│   │           └── sync_status_indicator.dart
│   ├── subscription/
│   │   ├── domain/
│   │   │   ├── subscription_repository.dart
│   │   │   └── subscription_model.dart
│   │   ├── data/
│   │   │   └── revenuecat_subscription_repository.dart
│   │   └── presentation/
│   │       ├── subscription_controller.dart  # @riverpod annotated
│   │       └── paywall_screen.dart
│   └── notifications/
│       ├── domain/
│       │   └── notification_repository.dart
│       ├── data/
│       │   └── onesignal_notification_repository.dart
│       └── presentation/
│           └── notification_settings_screen.dart
├── gen/                          # flutter_gen output
└── i18n/                         # slang output
    └── strings.g.dart

test/
├── core/
│   ├── database/
│   │   └── powersync_connector_test.dart
│   └── router/
│       └── app_router_test.dart
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   └── mock_auth_repository.dart
│   │   ├── data/
│   │   │   └── supabase_auth_repository_test.dart
│   │   └── presentation/
│   │       ├── auth_controller_test.dart
│   │       ├── login_screen_test.dart
│   │       └── otp_verify_screen_test.dart
│   ├── notes/
│   │   ├── domain/
│   │   │   └── mock_note_repository.dart
│   │   ├── data/
│   │   │   └── powersync_note_repository_test.dart
│   │   └── presentation/
│   │       ├── notes_controller_test.dart
│   │       └── notes_list_screen_test.dart
│   └── subscription/
│       ├── domain/
│       │   └── mock_subscription_repository.dart
│       └── presentation/
│           └── subscription_controller_test.dart
└── helpers/
    └── test_helpers.dart          # Shared mocks, pump helpers

supabase/
├── config.toml                    # Supabase CLI config
├── migrations/
│   ├── 00000000000000_create_notes.sql
│   └── 00000000000001_create_subscriptions.sql
├── seed.sql                       # Development seed data
└── functions/
    ├── revenuecat-webhook/
    │   └── index.ts               # RevenueCat webhook handler
    └── onesignal-trigger/
        └── index.ts               # Push notification trigger

config/
├── config_dev.json                # Dev environment (local Supabase)
├── config_staging.json            # Staging environment
└── config_prod.json               # Production environment

.github/
└── workflows/
    ├── test.yml                   # Run tests on PR
    ├── build-android.yml          # Build + deploy Android
    └── build-ios.yml              # Build + deploy iOS

fastlane/
├── Fastfile                       # Lane definitions
├── Appfile                        # App identifiers
└── Matchfile                      # Code signing config
```

**Initialization Order (Critical — performance-optimized):**

```dart
// main.dart — order matters. Non-critical SDKs deferred to post-first-frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment config
  final env = Env.fromDartDefines();

  // 2. Sentry wraps everything via appRunner
  await SentryFlutter.init(
    (options) => options..dsn = env.sentryDsn,
    appRunner: () async {
      // 3. Initialize Supabase (MUST be before PowerSync)
      //    Use flutter_secure_storage for JWT storage (SEC-2)
      await Supabase.initialize(
        url: env.supabaseUrl,
        anonKey: env.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(),
        ),
      );

      // 4. Initialize PowerSync (connects after auth)
      final db = PowerSyncDatabase(schema: schema);
      await db.init();

      // 5. Run app FIRST — render UI before non-critical init
      //    [PERF] Deferring PostHog/RevenueCat/OneSignal to post-first-frame
      //    cuts startup by ~50%, hitting <3s on cellular
      runApp(
        ProviderScope(
          observers: [SentryProviderObserver()],
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const App(),
        ),
      );

      // 6. Post-first-frame: initialize non-critical SDKs
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await Posthog().setup(PostHogConfig(apiKey: env.posthogApiKey));
        } catch (_) {} // Non-fatal — app works without analytics

        try {
          await Purchases.configure(
            PurchasesConfiguration(env.revenueCatApiKey),
          );
        } catch (_) {} // Non-fatal — paywall handles gracefully

        OneSignal.initialize(env.oneSignalAppId);
      });
    },
  );
}
```

**Dependency Direction Rules:**

- `core/` NEVER imports from `features/`
- `features/` NEVER import from other `features/`
- `domain/` NEVER imports from `data/` or `presentation/`
- `presentation/` imports from `domain/` only (never `data/`)
- Cross-feature coordination goes through `core/session/` or `core/providers/`

**Platform Requirements:**

- iOS minimum deployment target: 13.0
- Android compileSdkVersion: 34
- Android: `FlutterFragmentActivity` (required by RevenueCat paywalls)
- Android: `launchMode` must be `standard` or `singleTop`
- iOS: Notification Service Extension target (OneSignal)
- Both: `AUTO_INIT=false` for PostHog in AndroidManifest.xml and Info.plist

### Implementation Phases

#### Phase 1: Foundation

**Goal:** Initialized Flutter project with all dependencies and strict linting.

**Tasks:**

- [x] Run `flutter create --org com.example flutter_supabase_starter` (or
      similar)
- [x] Add all dependencies to `pubspec.yaml`:
  - Core: `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`,
    `go_router`
  - Data: `supabase_flutter`, `powersync` (latest with Rust client)
  - Monetization: `purchases_flutter`
  - Push: `onesignal_flutter`
  - Observability: `sentry_flutter`, `posthog_flutter`
  - i18n/Assets: `slang`, `slang_flutter`, `flutter_gen`
  - Dev: `build_runner`, `riverpod_lint`, `very_good_analysis`, `mocktail`
- [x] Configure `analysis_options.yaml` with `very_good_analysis` and
      `riverpod_lint`
- [x] Initialize Supabase CLI: `supabase init`
- [x] Create `config_dev.json`, `config_staging.json`, `config_prod.json` with
      placeholder keys
- [x] Set iOS minimum deployment target to 13.0
- [x] Set Android compileSdkVersion to 34
- [x] Change Android `MainActivity` to extend `FlutterFragmentActivity`
- [x] Set Android `launchMode` to `singleTop` in AndroidManifest.xml
- [x] Configure PostHog `AUTO_INIT=false` in AndroidManifest.xml and Info.plist
- [x] Create `.gitignore` with Flutter defaults + `config_prod.json` +
      `config_staging.json`
- [x] Create `.env.example` listing all required environment variable names (no
      values)
- [x] **Update AGENTS.md** — replace `shadcn_ui` references with Material 3 +
      custom theme (do this NOW, not Phase 7, so all agents use correct UI
      system)
- [x] Add `flutter_secure_storage` to dependencies (for secure JWT storage —
      SEC-2)
- [x] Verify: `flutter analyze` passes with zero warnings

**Success criteria:** `flutter analyze` and `flutter test` both pass (no tests
yet, just no errors).

#### Phase 2: Core Infrastructure

**Goal:** Environment loading, observability, theme, routing, codegen, and i18n
all working.

**Tasks:**

- [x] Implement `lib/core/env/env.dart` — load `--dart-define-from-file` values
- [x] Implement `lib/core/observability/sentry_config.dart` — Sentry
      initialization
- [x] Implement `lib/core/observability/posthog_config.dart` — PostHog
      initialization
- [x] Implement `lib/core/observability/provider_observer.dart` — Riverpod
      ProviderObserver that sends unhandled exceptions to Sentry
- [x] Implement `lib/core/theme/app_colors.dart` — centralized Material 3 color
      palette (light + dark)
- [x] Implement `lib/core/theme/app_typography.dart` — typography scale
- [x] Implement `lib/core/theme/app_theme.dart` — `ThemeData` using
      `colorSchemeSeed` with app_colors
- [x] Configure `flutter_gen` in `pubspec.yaml` — assets directory, output
- [x] Configure `slang` — create `i18n/strings.i18n.json` with initial strings
- [x] Configure `build.yaml` for multi-generator performance:
  - Scope `riverpod_generator` to `lib/features/**/presentation/`
  - Scope `flutter_gen_runner` to assets
  - Scope `slang_build_runner` to `i18n/`
  - Set `runs_before` ordering
- [x] Implement `lib/core/router/app_router.dart` — GoRouter with:
  - Auth redirect using `refreshListenable` pattern (listens to Supabase auth
    state)
  - Routes: `/login`, `/otp-verify`, `/notes` (home), `/note/:id`, `/settings`,
    `/paywall`
  - Global redirect: unauthenticated → `/login`, authenticated → `/notes`
- [x] Implement `lib/core/session/session_manager.dart` — Mediator pattern:
  - Orchestrates sign-out across all SDKs (PowerSync, RevenueCat, OneSignal,
    Supabase)
  - Decouples auth repository from other SDKs (architecture review finding #2)
  - Single point of coordination for cross-feature session lifecycle
- [x] Implement `lib/core/widgets/async_value_widget.dart` — reusable widget:
  - Handles `AsyncValue` states (data/loading/error) consistently across all
    screens
  - Prevents each screen from reinventing error/loading UI
- [x] Implement `lib/core/widgets/error_screen.dart` — full-screen error with
      retry button
- [x] Implement `lib/core/providers/database_providers.dart` — shared Riverpod
      providers for PowerSync + Supabase
- [x] Implement `lib/core/providers/connectivity_provider.dart` — network status
      stream
- [x] Add `FlutterError.onError` and `PlatformDispatcher.instance.onError`
      handlers in `main.dart`
- [x] Wrap each non-critical init step with try/catch — only Supabase +
      PowerSync are fatal
- [x] Implement `lib/main.dart` with full initialization order (see above)
- [x] Run `dart run build_runner build` — verify all generators work
- [x] Write tests for router redirects
- [x] Verify: app launches with theme applied, routes to login screen

**Success criteria:** App launches, shows themed login placeholder, router
redirects work, codegen produces clean output.

#### Phase 3: Data Layer

**Goal:** Supabase client and PowerSync local database configured with sync
working.

**Tasks:**

- [x] Implement `lib/core/database/supabase_client.dart` — singleton accessor
- [x] Write Supabase migration (notes):
      `supabase/migrations/00000000000000_create_notes.sql`
  - `notes` table: `id uuid PK default gen_random_uuid()`,
    `user_id uuid NOT NULL references auth.users ON DELETE CASCADE DEFAULT auth.uid()`,
    `title text NOT NULL`, `body text`,
    `created_at timestamptz NOT NULL default now()`,
    `updated_at timestamptz NOT NULL default now()`
  - **`updated_at` trigger** (CRITICAL): Create trigger function to auto-update
    `updated_at` on row modification — required for server-wins conflict
    resolution
  - **Indexes:**
    `CREATE INDEX idx_notes_user_id_created ON notes (user_id, created_at DESC);`
    and `CREATE INDEX idx_notes_updated_at ON notes (updated_at);`
  - **RLS policies** (per-operation — see
    `docs/plans/2026-03-10-database-design-recommendations.md`):
    - `ALTER TABLE notes ENABLE ROW LEVEL SECURITY;`
    - `ALTER TABLE notes FORCE ROW LEVEL SECURITY;`
    - Separate SELECT, INSERT (with `WITH CHECK`), UPDATE (both `USING` and
      `WITH CHECK`), DELETE policies scoped to `auth.uid() = user_id`
- [x] Write Supabase migration (subscriptions):
      `supabase/migrations/00000000000001_create_subscriptions.sql`
  - `subscriptions` table: `id uuid PK`,
    `user_id uuid NOT NULL UNIQUE references auth.users ON DELETE CASCADE`,
    `status text NOT NULL CHECK (status IN ('active','expired','cancelled','trial'))`,
    `product_id text NOT NULL`, `expires_at timestamptz`,
    `created_at timestamptz NOT NULL default now()`,
    `updated_at timestamptz NOT NULL default now()`
  - **Indexes:**
    `CREATE INDEX idx_subscriptions_user_id ON subscriptions (user_id);` and
    `CREATE INDEX idx_subscriptions_active ON subscriptions (expires_at) WHERE status = 'active';`
  - **RLS policies:** `ENABLE + FORCE RLS`. SELECT only for authenticated users.
    No INSERT/UPDATE/DELETE for authenticated role — only service_role (Edge
    Function) can write
  - **GRANT:** Explicit `GRANT SELECT ON subscriptions TO authenticated;`
- [x] Create Postgres publication **inside a migration** (for reproducibility):
      `CREATE PUBLICATION powersync FOR TABLE notes, subscriptions;`
- [x] Define PowerSync schema in Dart — `Schema` with `notes` and
      `subscriptions` tables
- [ ] Configure PowerSync Sync Streams (edition 3) — sync rules for per-user
      data filtering
- [x] Implement `lib/core/database/powersync_connector.dart`:
  - `fetchCredentials()` — get JWT from Supabase auth session for PowerSync;
    check `session.expiresAt` and call `refreshSession()` if token expires
    within 60 seconds (SEC-2)
  - `uploadData()` — batch CRUD uploads using `getCrudBatch(limit: 100)` to
    prevent OOM on large offline queues (performance P0)
- [x] Implement `lib/core/database/powersync_client.dart` — database singleton
      with schema
- [x] Handle sign-out: **clear local PowerSync SQLite data** when user signs out
      (privacy requirement)
- [x] Write `supabase/seed.sql` — development seed data
- [x] Write tests for PowerSync connector (mock Supabase auth for credentials)
- [ ] Verify: `supabase start`, run migration, confirm tables + RLS policies
      exist

**Success criteria:** Local Supabase running, tables created with RLS, PowerSync
schema defined, connector tested.

#### Phase 4: Authentication Feature (TDD)

**Goal:** Complete Email OTP auth flow following strict TDD workflow.

**TDD Sequence (per AGENTS.md):**

1. **Domain first:**
   - [x] `lib/features/auth/domain/user_model.dart` — User entity (id, email,
         createdAt)
   - [x] `lib/features/auth/domain/auth_repository.dart` — Abstract interface:
     - `Future<void> sendOtp(String email)`
     - `Future<User> verifyOtp(String email, String token)`
     - `Future<void> signOut()`
     - `Stream<User?> authStateChanges()`

2. **Mocks + Tests:**
   - [x] `test/helpers/pump_app.dart` — shared helper that wraps widgets in
         `MaterialApp` + `ProviderScope` with all required overrides for widget
         tests (reused across all features)
   - [x] `test/features/auth/domain/mock_auth_repository.dart` — mocktail mock
   - [x] `test/features/auth/presentation/auth_controller_test.dart`:
     - Test: sendOtp triggers loading → success states
     - Test: sendOtp with invalid email → error state
     - Test: verifyOtp with valid token → authenticated
     - Test: verifyOtp with expired/wrong OTP → error with message
     - Test: signOut clears state and local data
     - Test: auth state stream updates on sign-in/sign-out
   - [x] `test/features/auth/presentation/login_screen_test.dart`:
     - Test: renders email input and submit button
     - Test: shows validation error for empty/invalid email
     - Test: shows loading state while sending OTP
     - Test: navigates to OTP screen on success
     - Test: shows error snackbar on failure
   - [x] `test/features/auth/presentation/otp_verify_screen_test.dart`:
     - Test: renders OTP input field
     - Test: shows loading during verification
     - Test: navigates to home on success
     - Test: shows error for wrong code
     - Test: resend OTP button with cooldown timer

3. **Implementation:**
   - [x] `lib/features/auth/data/supabase_auth_repository.dart`:
     - `sendOtp` → `supabase.auth.signInWithOtp(email: email)`
     - `verifyOtp` →
       `supabase.auth.verifyOTP(email: email, token: token, type: OtpType.email)`
     - `signOut` → delegates to `SessionManager.signOut()` (NOT directly to
       SDKs)
     - `authStateChanges` → `supabase.auth.onAuthStateChange` mapped to User
   - [x] `SessionManager.onSignIn(userId)` called after successful auth:
     - `Purchases.logIn(userId)` — RevenueCat (MUST happen before any purchase)
     - `OneSignal.login(userId)` — push notification targeting
     - `PowerSync.connect()` — start sync with valid JWT
   - [x] `SessionManager.signOut()` orchestrates full cleanup:
     - `PowerSync.disconnectAndClear()` — clear local data
     - `Purchases.logOut()` — RevenueCat
     - `OneSignal.logout()` — push notifications
     - `Supabase.auth.signOut()` — auth session
     - Clear any in-memory cached user data

4. **Presentation:**
   - [x] `lib/features/auth/presentation/auth_controller.dart` — `@riverpod`
         annotated controller
   - [x] `lib/features/auth/presentation/login_screen.dart` — Material 3 themed,
         email input, submit
   - [x] `lib/features/auth/presentation/otp_verify_screen.dart` — OTP input,
         verify, resend

**Auth error states to handle:**

- Invalid email format (client-side validation)
- OTP expired (Supabase returns specific error)
- Wrong OTP code (max 3 attempts, then re-send)
- Rate limiting (show "try again in X seconds")
- Network loss during auth flow (show offline message, retry option)
- Session refresh/expiry (auto-refresh via Supabase client, redirect to login if
  expired)

**Success criteria:** All auth tests pass, full OTP flow works end-to-end,
sign-out clears local data.

#### Phase 5: Sample Feature — Notes (TDD)

**Goal:** Demonstrate the full offline-first CRUD architecture with a "Notes"
feature.

**Why this phase exists:** A starter kit without a working example feature
doesn't demonstrate the architecture to users. Notes is the simplest possible
feature that exercises every layer: PowerSync CRUD, Riverpod state, offline
indicators, sync status.

**TDD Sequence:**

1. **Domain:**
   - [x] `lib/features/notes/domain/note_model.dart` — Note entity (id, userId,
         title, body, createdAt, updatedAt)
   - [x] `lib/features/notes/domain/note_repository.dart` — Abstract interface:
     - `Future<List<Note>> getNotes({int limit = 50, int offset = 0})`
     - `Stream<List<Note>> watchNotes({int limit = 50})` — paginated from day
       one (performance P1)
     - `Future<Note> getNote(String id)`
     - `Future<Note> createNote(String title, String body)`
     - `Future<Note> updateNote(String id, {String? title, String? body})`
     - `Future<void> deleteNote(String id)`

2. **Mocks + Tests:**
   - [x] `test/features/notes/domain/mock_note_repository.dart`
   - [x] `test/features/notes/presentation/notes_controller_test.dart`:
     - Test: watchNotes streams note list
     - Test: createNote adds to list
     - Test: updateNote modifies existing
     - Test: deleteNote removes from list
     - Test: operations work offline (mocked)
   - [x] `test/features/notes/presentation/notes_list_screen_test.dart`:
     - Test: renders list of notes
     - Test: empty state shown when no notes
     - Test: pull-to-refresh triggers sync
     - Test: FAB navigates to create
     - Test: sync status indicator shows connectivity state
   - [x] `test/features/notes/data/powersync_note_repository_test.dart`:
     - Test: CRUD operations produce correct SQL

3. **Implementation:**
   - [x] `lib/features/notes/data/powersync_note_repository.dart` — raw SQL via
         PowerSync
   - [x] All reads/writes target local PowerSync SQLite (offline-first per
         AGENTS.md)
   - [x] `lib/features/notes/presentation/notes_controller.dart` — `@riverpod`
         with `AsyncValue`
   - [x] `lib/features/notes/presentation/notes_list_screen.dart` — Material 3
         list
   - [x] `lib/features/notes/presentation/note_detail_screen.dart` — view/edit
         with auto-save
   - [x] `lib/features/notes/presentation/widgets/note_card.dart` — list item
         widget
   - [x] `lib/features/notes/presentation/widgets/sync_status_indicator.dart` —
         shows online/offline/syncing
   - [x] Use `ListView.builder` (not `ListView`) for notes list with
         `itemExtent` or `prototypeItem` for scroll performance
   - [x] Use `const` constructors on all stateless widgets (NoteCard, etc.) to
         prevent unnecessary rebuilds
   - [x] Add pull-to-refresh on notes list using `RefreshIndicator`
   - [x] Add golden tests for design system widgets (NoteCard,
         SyncStatusIndicator) to catch visual regressions

**Success criteria:** Full CRUD works offline, syncs when online, tests pass,
serves as architecture reference.

#### Phase 6: Subscriptions & Push Notifications

**Goal:** RevenueCat paywall and OneSignal push notifications integrated.

**Tasks:**

**Subscriptions (TDD):**

- [x] `lib/features/subscription/domain/subscription_model.dart`
- [x] `lib/features/subscription/domain/subscription_repository.dart` — abstract
      interface
- [x] `test/features/subscription/domain/mock_subscription_repository.dart`
- [x] `test/features/subscription/presentation/subscription_controller_test.dart`
- [x] `lib/features/subscription/data/revenuecat_subscription_repository.dart`:
  - Check entitlements on app launch
  - Listen to `Purchases.addCustomerInfoUpdateListener`
  - Expose subscription status as Riverpod provider
- [x] `lib/features/subscription/presentation/subscription_controller.dart`
- [x] `lib/features/subscription/presentation/paywall_screen.dart` — RevenueCat
      paywall UI

**Supabase Edge Functions — shared infrastructure:**

- [ ] `supabase/functions/_shared/supabase-client.ts` — shared Supabase client
      with service_role key
- [ ] `supabase/functions/_shared/types.ts` — discriminated union types for
      RevenueCat events
- [ ] `supabase/functions/_shared/responses.ts` — standard JSON error/success
      response helpers
- [ ] `supabase/functions/import_map.json` — pin dependency versions

**Supabase Edge Function — RevenueCat webhook:**

- [ ] `supabase/functions/revenuecat-webhook/handler.ts` — extracted for
      testability:
  - Verify `Authorization` bearer token with **constant-time comparison**
    (crypto.subtle HMAC — see
    `docs/reviews/2026-03-10-edge-functions-typescript-review.md`)
  - Parse event using typed discriminated unions (INITIAL_PURCHASE, RENEWAL,
    CANCELLATION, EXPIRATION)
  - Validate `app_user_id` is a valid UUID (not `$RCAnonymousID`) — return 400
    if anonymous
  - Use **service_role key** to bypass RLS (no user session in webhook context)
  - Upsert `subscriptions` table with `ON CONFLICT (user_id) DO UPDATE`
  - Idempotency: deduplicate on RevenueCat event `id`
  - Log to `webhook_audit_log` table for non-repudiation
  - Return generic error messages (never leak stack traces)
- [ ] `supabase/functions/revenuecat-webhook/index.ts` — `Deno.serve()` entry
      point (NOT deprecated `serve` import)
- [ ] **Tests:** `supabase/functions/revenuecat-webhook/handler_test.ts` — Deno
      test runner (TDD gap identified by TypeScript reviewer)

**Push Notifications:**

- [x] `lib/features/notifications/domain/notification_repository.dart`
- [x] `lib/features/notifications/data/onesignal_notification_repository.dart`:
  - Request permission on first relevant screen (not on app launch)
  - Handle permission denied gracefully
  - `OneSignal.login(userId)` called after auth
- [x] `lib/features/notifications/presentation/notification_settings_screen.dart`
- [ ] iOS: Add Notification Service Extension target (OneSignal requirement — 7
      steps)
- [ ] `supabase/functions/onesignal-trigger/index.ts` — Edge Function to send
      notifications

**Success criteria:** Paywall shows offerings, webhook processes events, push
notifications deliver on both platforms.

#### Phase 7: CI/CD & Developer Experience

**Goal:** GitHub Actions pipelines, Fastlane config, and developer setup
automation.

**GitHub Actions** (see `docs/plans/2026-03-10-cicd-recommendations.md` for full
YAML):

- [ ] `.github/workflows/test.yml`:
  - Trigger: PR to main, with concurrency control (cancel stale runs)
  - Steps: checkout, Flutter setup (with SDK caching via
    `subosito/flutter-action`), pub cache (keyed on `pubspec.lock`),
    `dart run build_runner build`, `dart format --set-exit-if-changed .`,
    `flutter analyze`, `flutter test --coverage`
  - Coverage threshold gate (80% minimum)
  - Test randomization for flaky test detection
- [ ] `.github/workflows/build-android.yml`:
  - Trigger: tag push (not every push to main)
  - Steps: checkout, Flutter setup, Java 17 + Gradle caching, **generate
    config_prod.json from GitHub Secrets**,
    `flutter build appbundle --dart-define-from-file=config_prod.json --obfuscate --split-debug-info=build/debug-info`,
    upload to Google Play via Fastlane
  - Protected environment with required reviewers
  - Always() cleanup of keystore artifacts
- [ ] `.github/workflows/build-ios.yml`:
  - Trigger: tag push
  - Runner: `macos-14` (Apple Silicon — 2-3x faster)
  - Steps: checkout, Flutter setup, CocoaPods caching (keyed on `Podfile.lock`),
    Fastlane Match `--readonly`, **generate config_prod.json from GitHub
    Secrets**,
    `flutter build ipa --dart-define-from-file=config_prod.json --obfuscate --split-debug-info=build/debug-info`,
    upload to TestFlight
  - App Store Connect API key auth (avoids 2FA issues)
- [ ] `.github/workflows/deploy-supabase.yml` (NEW — identified as critical
      gap):
  - Deploy Edge Functions: `supabase functions deploy revenuecat-webhook` and
    `onesignal-trigger`
  - Run database migrations: `supabase db push`
  - Deploy sync rules
- [ ] **Document all 22 GitHub Secrets** required across workflows (see
      `docs/reviews/2026-03-10-cicd-deployment-review.md`)
- [ ] **Document rollback procedures** for: app stores (staged rollout), Edge
      Functions (redeploy previous version), migrations (down migration), sync
      rules

**Fastlane:**

- [ ] `fastlane/Fastfile` — lanes for `test`, `build_android`, `build_ios`,
      `deploy_android`, `deploy_ios`
- [ ] `fastlane/Appfile` — placeholder app identifiers
- [ ] `fastlane/Matchfile` — code signing configuration

**Testing:**

- [ ] Add `integration_test/offline_sync_test.dart` — end-to-end test for
      offline create → reconnect → verify sync completes
- [ ] Add startup performance measurement in `main.dart` using `Stopwatch` that
      logs initialization phase durations to Sentry as performance transactions
      (validates <3s non-functional requirement)

**Developer Setup:**

- [ ] Create `Makefile` with common commands:
  - `make setup` — install dependencies, run codegen
  - `make codegen` — `dart run build_runner build --delete-conflicting-outputs`
  - `make watch` — `dart run build_runner watch`
  - `make test` — `flutter test`
  - `make analyze` — `flutter analyze`
  - `make supabase-start` — `supabase start`
  - `make supabase-reset` — `supabase db reset`
- [ ] Create `README.md` with:
  - Quick start guide (clone → configure → run)
  - Required external service accounts (Supabase, PowerSync, RevenueCat,
    OneSignal, Sentry, PostHog)
  - Environment configuration instructions
  - Architecture overview with diagram
  - How to add a new feature (step-by-step following the Notes example)
  - How to run tests
  - Deployment guide

**Success criteria:** CI runs on PR, builds succeed, README enables a developer
to go from clone to running app.

## Alternative Approaches Considered

(see brainstorm:
docs/brainstorms/2026-03-10-flutter-supabase-starter-kit-brainstorm.md)

1. **Core + Feature Branches** — Rejected because merge conflicts between
   branches over time undermines maintainability. Users finding and merging the
   right branches adds friction.
2. **Layered with Feature Flags** — Rejected because conditional initialization
   logic and dead code paths add complexity without proportional benefit.

## System-Wide Impact

### Interaction Graph

```
App Launch → Sentry.init(appRunner:)
  → Supabase.initialize()
    → PowerSync.init() → PowerSync.connect(connector)
      → connector.fetchCredentials() → Supabase.auth.currentSession.accessToken
      → connector.uploadData() → Supabase REST API (batched CRUD)
    → Purchases.configure() → RevenueCat SDK
    → OneSignal.initialize()
    → runApp(ProviderScope(observers: [SentryProviderObserver]))

Auth Success → SessionManager.onSignIn(userId)
  → Purchases.logIn(userId) → OneSignal.login(userId)
  → PowerSync.connect() (now has valid JWT)

Sign Out → SessionManager.signOut()
  → PowerSync.disconnectAndClear() → Purchases.logOut()
  → OneSignal.logout() → Supabase.auth.signOut()
  → Clear in-memory caches → Router redirects to /login

RevenueCat Webhook → Edge Function → Verify signature → Upsert subscriptions table
  → PowerSync syncs subscription status to device
```

### Error & Failure Propagation

- **Supabase init failure:** Sentry captures, app shows "connection error"
  screen
- **PowerSync sync failure:** Local data still works, sync retries automatically
- **RevenueCat failure:** Paywall shows error state, subscription checks fall
  back to cached
- **OTP verification failure:** Error message shown, user can retry or resend
- **Network loss:** App continues with local PowerSync data, sync status
  indicator shows offline
- **Unhandled exceptions:** Caught by Riverpod `ProviderObserver` → sent to
  Sentry automatically

### State Lifecycle Risks

- **Sign-out without clearing local data** → Next user sees previous user's
  notes. **Mitigation:** `PowerSync.disconnectAndClear()` on sign-out is
  mandatory.
- **RevenueCat anonymous ID** → Webhooks can't match to Supabase user.
  **Mitigation:** Always call `Purchases.logIn(userId)` immediately after
  successful auth.
- **PowerSync sync without Postgres publication** → No data syncs, silent
  failure. **Mitigation:** Migration includes `CREATE PUBLICATION powersync`.

### API Surface Parity

All data operations go through abstract repository interfaces in `domain/`. The
concrete implementations in `data/` can be swapped (e.g., for testing with mocks
or for a different backend) without touching `presentation/`.

### Integration Test Scenarios

1. **Full auth flow:** Send OTP → verify → land on notes screen → sign out →
   redirect to login → local data cleared
2. **Offline CRUD:** Create note while offline → go online → note appears in
   Supabase → another device sees it
3. **Subscription purchase:** Open paywall → complete purchase → webhook fires →
   subscription status syncs to device
4. **Session expiry:** Auth token expires → PowerSync connector refreshes JWT →
   sync continues without user action
5. **Multi-device conflict:** Edit same note on two devices offline → both come
   online → server-wins resolution applied

## Acceptance Criteria

### Functional Requirements

- [ ] Email OTP authentication works end-to-end (send, verify, sign out)
- [ ] Notes CRUD works fully offline and syncs when online
- [ ] Sync status indicator accurately shows online/offline/syncing states
- [ ] RevenueCat paywall displays offerings and processes purchases
- [ ] RevenueCat webhook correctly updates subscription status in Supabase
- [ ] OneSignal push notifications deliver on both iOS and Android
- [ ] Sign-out clears all local PowerSync data
- [ ] Supabase RLS policies prevent cross-user data access
- [ ] All user-facing strings are in slang i18n files
- [ ] All asset references use flutter_gen `Assets` class
- [ ] Light and dark Material 3 themes work correctly

### Non-Functional Requirements

- [ ] `flutter analyze` passes with zero warnings (very_good_analysis +
      riverpod_lint)
- [ ] Test coverage ≥ 80% across all features
- [ ] App launches in < 3 seconds on mid-range device
- [ ] Offline-to-online sync completes within 5 seconds for < 100 records
- [ ] iOS minimum deployment target: 13.0
- [ ] Android compileSdkVersion: 34

### Quality Gates

- [ ] All TDD sequences followed (domain → mocks → tests → data → presentation)
- [ ] No direct Supabase queries outside Auth/Edge Functions/Storage (per
      AGENTS.md)
- [ ] No manual try/catch for logging (ProviderObserver handles it)
- [ ] No hardcoded asset strings or user-facing strings
- [ ] README enables clone-to-running in < 30 minutes (with service accounts)
- [ ] AGENTS.md updated to reflect Material 3 decision

## Dependencies & Prerequisites

**External Service Accounts Required:**

1. Supabase project (or local via `supabase start`)
2. PowerSync account + instance
3. RevenueCat project + API keys
4. OneSignal app + API key
5. Sentry project + DSN
6. PostHog project + API key
7. Apple Developer account (for iOS builds + OneSignal)
8. Google Play Console (for Android builds)

**Local Development Prerequisites:**

- Flutter SDK (stable channel, latest)
- Docker (for Supabase CLI local development)
- Supabase CLI
- Xcode (for iOS builds)
- Android Studio (for Android builds)

## Risk Analysis & Mitigation

| Risk                                      | Impact | Likelihood | Mitigation                                                |
| ----------------------------------------- | ------ | ---------- | --------------------------------------------------------- |
| PowerSync breaking changes                | High   | Medium     | Pin version in pubspec.yaml, test sync thoroughly         |
| Riverpod 3.0 instability                  | Medium | Medium     | Follow migration guide, test AsyncValue behavior          |
| RevenueCat webhook anonymous IDs          | High   | High       | logIn(userId) immediately after auth, validate in webhook |
| OneSignal iOS setup complexity            | Medium | High       | Document all 7 steps explicitly, test on real device      |
| build_runner conflicts between generators | Medium | Medium     | Scope each generator in build.yaml with generate_for      |
| Local data privacy on shared devices      | High   | Medium     | Mandatory PowerSync.disconnectAndClear() on sign-out      |

## Security Analysis (STRIDE-Based)

The following security recommendations were derived by applying STRIDE threat
modeling, attack tree analysis, and security requirement extraction to this
plan's architecture. Focus areas: Supabase RLS, auth token handling, webhook
security, secret management, and mobile app security.

### SEC-1: Supabase Row-Level Security (RLS) Hardening

**STRIDE category:** Elevation of Privilege, Information Disclosure

The plan mentions RLS for `notes` and `subscriptions`, but the policies need to
be more specific and comprehensive:

- [ ] **Write explicit RLS policies per operation** — do not rely on a single
      `USING (auth.uid() = user_id)` for all operations. Define separate
      `SELECT`, `INSERT`, `UPDATE`, `DELETE` policies:
  - `INSERT` policy must include `WITH CHECK (auth.uid() = user_id)` to prevent
    a user from inserting rows with another user's `user_id`
  - `UPDATE` policy should use both `USING` and `WITH CHECK` to prevent
    ownership transfer via update
  - `DELETE` policy must use `USING (auth.uid() = user_id)`
- [ ] **Add RLS to the `subscriptions` table for all operations** — the plan
      says "users can only read" but the webhook Edge Function writes via
      service role key. Ensure: `SELECT` policy for authenticated users, no
      `INSERT`/`UPDATE`/`DELETE` for authenticated role (only service role can
      write)
- [ ] **Verify RLS is enabled and forced** — add to each migration:
      `ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;` and
      `ALTER TABLE <table> FORCE ROW LEVEL SECURITY;` (FORCE ensures RLS applies
      even to table owners in non-superuser contexts)
- [ ] **Test RLS policies explicitly** — add integration tests that attempt
      cross-user data access and confirm denial. Example: User A creates a note,
      User B queries notes, User B should get zero results
- [ ] **Audit PowerSync sync rules** — ensure PowerSync Sync Streams filtering
      mirrors RLS policies. A misconfigured sync rule could leak data to other
      users even if RLS is correct on direct queries

### SEC-2: Auth Token & Session Security

**STRIDE category:** Spoofing, Tampering

- [ ] **Secure JWT storage** — Supabase Flutter SDK stores tokens in
      `SharedPreferences` (Android) / `NSUserDefaults` (iOS) by default.
      Override with `flutter_secure_storage` to use Android Keystore / iOS
      Keychain:
  ```dart
  // In Supabase.initialize, pass a custom localStorage
  await Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(), // Custom impl using flutter_secure_storage
    ),
  );
  ```
- [ ] **Handle token refresh race conditions** — PowerSync's
      `fetchCredentials()` gets the JWT from the current Supabase session. Add
      logic to check `session.expiresAt` and call
      `supabase.auth.refreshSession()` if the token expires within 60 seconds,
      before returning credentials to PowerSync
- [ ] **Invalidate all sessions on password/email change** — if the template
      adds account management later, ensure `signOut()` is called on all devices
      (Supabase supports global sign-out)
- [ ] **OTP brute-force protection** — the plan mentions "max 3 attempts, then
      re-send" but this must be enforced server-side via Supabase rate limiting
      config, not just client-side UI. Verify Supabase project auth settings
      have appropriate rate limits configured
- [ ] **Clear auth state completely on sign-out** — in addition to
      `PowerSync.disconnectAndClear()`, ensure: Supabase session cleared,
      RevenueCat logged out (`Purchases.logOut()`), OneSignal logged out
      (`OneSignal.logout()`), any in-memory cached user data nullified. The plan
      covers this in the interaction graph but it should be an explicit
      checklist in the auth repository implementation

### SEC-3: Webhook Security (RevenueCat Edge Function)

**STRIDE category:** Spoofing, Tampering, Repudiation

The RevenueCat webhook handler is a critical attack surface:

- [ ] **Verify webhook authorization token** — RevenueCat sends an
      `Authorization` header with each webhook. The Edge Function must:
  1. Read the `Authorization` header from the request
  2. Compare against the webhook auth key stored in Supabase Edge Function
     secrets (`Deno.env.get('REVENUECAT_WEBHOOK_AUTH_KEY')`)
  3. Return 401 immediately if the token does not match
  4. Use constant-time string comparison to prevent timing attacks
- [ ] **Validate request payload schema** — parse and validate the webhook body
      against expected RevenueCat event types. Reject unexpected event types or
      malformed payloads with 400
- [ ] **Use Supabase service role key in Edge Functions** — the Edge Function
      must use the service role key (not the anon key) to bypass RLS and write
      to the `subscriptions` table. Store as `SUPABASE_SERVICE_ROLE_KEY` secret
      via `supabase secrets set`
- [ ] **Idempotency** — RevenueCat may send duplicate webhooks. Use the event
      `id` field as an idempotency key (upsert on `id` or maintain a processed
      events log)
- [ ] **Log all webhook events** — for non-repudiation, log every webhook
      invocation (event type, app_user_id, timestamp) to a separate
      `webhook_audit_log` table. This enables debugging subscription disputes
- [ ] **Apply the same pattern to the OneSignal trigger Edge Function** —
      authenticate incoming requests and validate payloads

### SEC-4: Secret & Configuration Management

**STRIDE category:** Information Disclosure

- [ ] **Never commit production or staging secrets** — the plan has
      `config_prod.json` in `.gitignore` which is good, but also ensure
      `config_staging.json` is gitignored. Only `config_dev.json` (pointing to
      local Supabase) should be committed
- [ ] **Document which keys are safe to embed in the app** — Supabase anon key,
      PostHog API key, OneSignal App ID, and RevenueCat public API key are
      designed to be public (embedded in client apps). Make this explicit in
      README to prevent confusion
- [ ] **Never embed service role keys in the Flutter app** — the Supabase
      service role key must only exist in Edge Function secrets. Add a comment
      or lint rule to flag any reference to service role keys in `lib/`
- [ ] **Supabase Edge Function secrets** — store via `supabase secrets set`:
  - `REVENUECAT_WEBHOOK_AUTH_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY` (for Edge Functions to bypass RLS)
  - `ONESIGNAL_REST_API_KEY` (for server-to-server push triggers)
- [ ] **GitHub Actions secrets** — store all production config values as
      repository secrets, inject via `--dart-define-from-file` using a generated
      config file in CI. Never echo secrets in workflow logs
- [ ] **Add a pre-commit hook or CI check** — scan for accidentally committed
      secrets (API keys, DSNs) using a tool like `gitleaks` or `trufflehog`

### SEC-5: Mobile App Security

**STRIDE category:** Tampering, Information Disclosure

- [ ] **Certificate pinning** — document how template users should add TLS
      certificate pinning for production domains (options:
      `http_certificate_pinning`, Network Security Config on Android, ATS on
      iOS). Not wired in the starter kit — production-specific
- [ ] **Root/jailbreak detection** — document as a production recommendation for
      apps handling payments (options: `flutter_jailbreak_detection`,
      `freerasp`). Not wired in the starter kit — production-specific
- [ ] **Code obfuscation** — add
      `--obfuscate --split-debug-info=build/debug-info` to the release build
      commands in Fastlane and CI workflows. This is a Flutter best practice but
      must be explicitly configured
- [ ] **Disable debug logging in release** — ensure Sentry and PostHog are not
      sending debug-level data in production. Use `kReleaseMode` or the
      environment config to gate log verbosity
- [ ] **Secure the local SQLite database** — document that PowerSync's local
      SQLite stores user data in plaintext. For sensitive apps, SQLCipher
      encryption is recommended. Production-specific — not wired in starter kit
- [ ] **Deep link validation** — the Supabase auth callback URL scheme
      (`io.supabase.flutter://callback`) can be intercepted by malicious apps.
      Use Android App Links (verified) and iOS Universal Links instead of custom
      URL schemes for production deployments. Document this upgrade path
- [ ] **Prevent screenshot/screen recording on sensitive screens** — document as
      optional: `FLAG_SECURE` (Android) and screen capture prevention (iOS) for
      OTP verification and paywall screens. Production-specific

### SEC-6: Edge Function & API Security

**STRIDE category:** Denial of Service, Tampering

- [ ] **Rate limit Edge Functions** — Supabase Edge Functions do not have
      built-in per-endpoint rate limiting. Implement rate limiting in the
      function code (e.g., track request counts per IP in a database table or
      use Supabase's `pg_net`) or place an upstream API gateway in front
- [ ] **Input validation in Edge Functions** — validate and sanitize all inputs
      in `revenuecat-webhook/index.ts` and `onesignal-trigger/index.ts`. Never
      trust client-supplied data. Use Zod or a similar TypeScript schema
      validation library in the Deno Edge Functions
- [ ] **CORS configuration** — Edge Functions should have strict CORS policies.
      Webhook endpoints should reject browser-based requests entirely (no
      `Access-Control-Allow-Origin` header)
- [ ] **Error responses** — never return stack traces or internal error details
      to callers. Return generic error messages (e.g.,
      `{ "error": "Bad request" }`) and log details server-side

### SEC-7: Observability & Incident Response

**STRIDE category:** Repudiation

- [ ] **Sentry PII scrubbing** — the plan enables `sendDefaultPii: true` in
      Sentry. Review what PII this includes (IP addresses, user agents, request
      headers). For GDPR compliance, consider setting this to `false` or
      configuring `beforeSend` to scrub sensitive fields
- [ ] **Audit logging** — add a database trigger or application-level logging
      for security-relevant events: failed auth attempts, RLS policy violations
      (via Supabase logs), subscription status changes, admin actions
- [ ] **Alerting** — configure Sentry alerts for unusual patterns: spike in auth
      failures (credential stuffing), unusual error rates in Edge Functions
      (webhook abuse), elevated 403 responses (RLS policy denials)

### Security Tasks by Phase

To integrate these recommendations into the existing implementation phases:

- **Phase 1:** Add `flutter_secure_storage` to dependencies, add `gitleaks`
  pre-commit hook, gitignore `config_staging.json`, add `.env.example`
- **Phase 2:** No security-specific additions (covered by existing tasks)
- **Phase 3:** Write explicit per-operation RLS policies with separate
  SELECT/INSERT/UPDATE/DELETE, add `FORCE ROW LEVEL SECURITY`, add RLS
  integration tests, audit PowerSync sync rules against RLS, document SQLite
  encryption option
- **Phase 4:** Implement secure token storage via `flutter_secure_storage`
  override, add token refresh logic in `fetchCredentials()`, verify server-side
  OTP rate limits, ensure complete sign-out state cleanup across all SDKs
- **Phase 5:** No security-specific additions (RLS already protects notes data)
- **Phase 6:** Implement webhook auth verification with constant-time
  comparison, add webhook audit logging table, validate all Edge Function inputs
  with Zod, add rate limiting, store all secrets via `supabase secrets set`, set
  strict CORS on webhook endpoints
- **Phase 7:** Add `--obfuscate` to release builds, add secret scanning to CI,
  configure Sentry PII scrubbing, document certificate pinning and root
  detection as production recommendations, document deep link upgrade path

## Documentation Plan

- [ ] `README.md` — Quick start, architecture overview, feature guide
- [ ] `docs/ARCHITECTURE.md` — Detailed architecture decisions and patterns
- [ ] Inline code comments where logic isn't self-evident (initialization order,
      sync connector)
- [ ] Each Edge Function includes a header comment explaining its purpose and
      trigger

## Sources & References

### Origin

- **Brainstorm document:**
  [docs/brainstorms/2026-03-10-flutter-supabase-starter-kit-brainstorm.md](docs/brainstorms/2026-03-10-flutter-supabase-starter-kit-brainstorm.md)
  — Key decisions: Material 3 over shadcn_ui, full offline CRUD with
  server-wins, Email OTP with social login designed for later, full monolith
  distribution as GitHub template.

### Internal References

- AGENTS.md — Architecture conventions, TDD workflow, linting rules
- docs/plan.md — Original master plan (6 phases)
- docs/STACK_BEST_PRACTICES.md — Best practices research
- docs/package-documentation-research.md — Package-specific documentation
- docs/analysis/2026-03-10-flow-analysis.md — SpecFlow gap analysis
- docs/analysis/2026-03-10-pattern-consistency-review.md — 16 pattern findings
- docs/reviews/2026-03-10-security-review.md — 21 security findings
- docs/reviews/2026-03-10-performance-review.md — 9 performance findings
- docs/reviews/2026-03-10-architecture-review.md — 9 architecture findings
- docs/reviews/2026-03-10-plan-simplicity-review.md — Scope analysis
- docs/reviews/2026-03-10-data-integrity-review.md — 14 data findings
- docs/reviews/2026-03-10-edge-functions-typescript-review.md — 10 TS findings
- docs/reviews/2026-03-10-cicd-deployment-review.md — CI/CD deployment checklist
- docs/plans/2026-03-10-cicd-recommendations.md — Full CI/CD YAML
- docs/plans/2026-03-10-database-design-recommendations.md — Complete SQL

### External References

- PowerSync Supabase integration guide
- Riverpod 3.0 migration guide
- RevenueCat Flutter SDK documentation
- OneSignal Flutter setup guide (iOS Notification Service Extension)
- Supabase Email OTP documentation
- PostHog Flutter SDK (manual initialization pattern)

### Research Findings (Key)

- Initialization order: Sentry(appRunner) → Supabase → PowerSync → RevenueCat →
  OneSignal → runApp
- PowerSync 1.17.0: Rust sync client default, Sync Streams edition 3,
  getCrudTransactions for batched uploads
- Riverpod 3.0: AsyncValue.value returns null during errors, Notifiers recreated
  on rebuild, mutations support
- RevenueCat: FlutterFragmentActivity required on Android, logIn before purchase
  events
- build.yaml: generate_for scoping critical for multi-generator performance
