# Architecture Review: Flutter & Supabase Starter Kit Plan

**Date:** 2026-03-10 **Reviewed:**
`docs/plans/2026-03-10-feat-flutter-supabase-starter-kit-plan.md` **Against:**
AGENTS.md, STACK_BEST_PRACTICES.md, package-documentation-research.md,
flow-analysis.md, plan.md

---

## 1. Architecture Overview

The plan describes a feature-first Flutter monolith with four features (auth,
notes, subscription, notifications) sharing a `core/` layer. Each feature
follows domain/data/presentation layering with abstract repository interfaces.
State management uses Riverpod 3.0 codegen. Data flows through PowerSync for
offline-first CRUD with Supabase as the backend. GoRouter provides centralized
routing with auth guards.

This is a sound architecture. The following findings address specific compliance
issues, anti-patterns, and structural improvements.

---

## 2. Compliance Check: What the Plan Gets Right

- **Repository pattern consistently applied.** All four features define abstract
  interfaces in `domain/` with concrete implementations in `data/`. This
  satisfies Dependency Inversion and enables testability.
- **Initialization order is correct.** Sentry wraps everything via `appRunner`,
  Supabase before PowerSync, PowerSync before `connect()`. This matches both
  STACK_BEST_PRACTICES.md and package-documentation-research.md.
- **TDD sequence is properly specified.** Domain -> mocks -> tests -> data ->
  presentation follows AGENTS.md exactly.
- **Sign-out data clearing is addressed.** The plan mandates
  `PowerSync.disconnectAndClear()` on sign-out, resolving the privacy gap
  identified in the flow analysis (Gap 3.10).
- **build.yaml generator scoping is planned.** Scoping `riverpod_generator` to
  `lib/features/**/presentation/` prevents unnecessary codegen runs.
- **RLS policies are specified per-table.** Each migration includes row-level
  security with `auth.uid() = user_id`.

---

## 3. Architectural Issues Found

### 3.1 CRITICAL: Missing `core/providers/` Layer for Dependency Injection

**Problem:** The plan's directory structure places database singletons in
`core/database/` but does not define a `core/providers/` directory for Riverpod
providers that expose these singletons to features. The STACK_BEST_PRACTICES.md
explicitly recommends `core/providers/supabase_provider.dart` and
`core/providers/powersync_provider.dart`.

The plan shows `databaseProvider.overrideWithValue(db)` in `main.dart`, which
implies a provider exists somewhere, but no file is listed for it.

**Risk:** Without explicit shared providers, features will either import
singletons directly (creating tight coupling to `core/database/`) or each
feature will create its own provider (duplication).

**Recommendation:** Add `lib/core/providers/` with:

- `database_provider.dart` -- exposes `PowerSyncDatabase` via `@riverpod`
- `supabase_provider.dart` -- exposes `SupabaseClient` via `@riverpod`
- `auth_state_provider.dart` -- exposes auth state stream as a shared provider

This is the Dependency Inversion seam that lets features depend on providers
rather than concrete singletons.

### 3.2 HIGH: PowerSync Schema Location Violates Feature Boundaries

**Problem:** The plan defines the PowerSync schema (with `notes` and
`subscriptions` tables) but does not specify where this schema lives. The
STACK_BEST_PRACTICES.md recommends a dedicated `lib/powersync/schema.dart`. The
plan's directory tree puts everything database-related in `core/database/`.

**Risk:** The PowerSync schema defines table structures for multiple features
(notes, subscriptions). Placing it in `core/database/` means `core/` has
knowledge of feature-specific table structures, violating the separation
principle. But splitting it per-feature is worse because PowerSync requires a
single unified `Schema` object.

**Recommendation:** Accept `core/database/powersync_schema.dart` as the correct
location, but document explicitly that this is the one place where feature table
definitions converge. Each feature's `data/` layer should define its own column
constants and query helpers, while the schema file only declares table names and
column types. This is an acceptable architectural trade-off for PowerSync's
single-schema requirement.

### 3.3 HIGH: Cross-Feature Coupling in Auth Sign-Out Flow

**Problem:** The plan specifies that sign-out must call
`PowerSync.disconnectAndClear()`, `Purchases.logOut()`, `OneSignal.logout()`,
and `Supabase.auth.signOut()`. This means the auth feature's
`supabase_auth_repository.dart` must know about PowerSync, RevenueCat, and
OneSignal -- four different SDK integrations in a single method.

**Risk:** This creates inappropriate intimacy between the auth feature and every
other feature. Adding a new service later (e.g., analytics reset) means
modifying the auth repository.

**Recommendation:** Introduce a `core/session/session_manager.dart` that
orchestrates sign-out across all services. The auth repository calls
`sessionManager.teardown()`, which delegates to each service. This follows the
Mediator pattern and keeps auth decoupled from subscription/notification
concerns. Similarly, sign-in should use a `sessionManager.setup(userId)` that
calls `Purchases.logIn()`, `OneSignal.login()`, and `PowerSync.connect()`.

### 3.4 MEDIUM: `auth_controller.g.dart` Listed Instead of `auth_controller.dart`

**Problem:** The plan's directory tree lists `auth_controller.g.dart` (the
generated file) but not `auth_controller.dart` (the source file you actually
write). Same for `notes_controller.g.dart` and `subscription_controller.g.dart`.
The `.g.dart` files are build_runner output and should never be listed as
authored files.

**Risk:** An AI agent following this plan literally would try to create
`.g.dart` files by hand instead of writing the `@riverpod` annotated source
files and running codegen.

**Recommendation:** Fix the directory tree to list the source files
(`auth_controller.dart`, `notes_controller.dart`,
`subscription_controller.dart`). Add a note that `.g.dart` files are generated
by `dart run build_runner build`.

### 3.5 MEDIUM: No Error Boundary / Fallback UI Strategy

**Problem:** The plan mentions `ProviderObserver` catching unhandled exceptions
and sending them to Sentry, and the error propagation section describes failure
states, but there is no architectural pattern for displaying error states to
users. Individual screens have test cases for error messages, but there is no
shared error handling widget or pattern.

**Risk:** Each screen will implement its own error handling UI, leading to
inconsistent UX and duplicated error presentation logic.

**Recommendation:** Add a `core/widgets/` directory with:

- `async_value_widget.dart` -- a generic widget that handles `AsyncValue<T>`
  states (loading, data, error) consistently across all screens
- `error_screen.dart` -- a full-screen error state for initialization failures
  (Supabase init failure, etc.)
- `offline_banner.dart` -- a persistent banner for connectivity status

This follows the DRY principle and gives template users a single pattern to
extend.

### 3.6 MEDIUM: Master Plan Inconsistency -- shadcn_ui References

**Problem:** The master plan (`docs/plan.md`) section 5 still references
`shadcn_ui` for theming ("5. UI Consistency: Only use `shadcn_ui` components"),
but the brainstorm and this plan explicitly decided on Material 3. AGENTS.md
section 5 also says "Use Material 3."

**Risk:** An AI agent reading `plan.md` or the coding guardrails will use
`shadcn_ui`. The plan's Phase 7 task to "Update AGENTS.md -- replace shadcn_ui
references with Material 3" should also cover `plan.md`.

**Recommendation:** Add a task in Phase 7 to update `docs/plan.md` section 6.5
to reference Material 3 instead of shadcn_ui. Better yet, do this before Phase 1
to prevent confusion.

### 3.7 MEDIUM: Missing Application Layer Between Domain and Presentation

**Problem:** The three-layer structure (domain/data/presentation) places
Riverpod controllers in `presentation/`. These controllers contain business
logic (e.g., "after auth success, call `Purchases.logIn`") mixed with state
management for the UI.

**Risk:** Controllers become bloated with orchestration logic. Testing business
rules requires setting up UI-layer test infrastructure (ProviderScope, etc.).

**Recommendation:** For this starter kit's scope, the three-layer approach is
pragmatically acceptable. However, document in `ARCHITECTURE.md` that if a
controller exceeds ~100 lines of business logic, it should be refactored into a
`domain/use_case/` or `domain/service/` that the controller delegates to. This
gives template users an upgrade path without over-engineering the initial
implementation.

### 3.8 LOW: No Explicit Dependency Direction Rules

**Problem:** The plan establishes feature-first structure and repository
pattern, but does not state the allowed dependency directions. For example: Can
the `notes` feature import from `auth`? Can `subscription` import from `notes`?

**Risk:** Without explicit rules, features will gradually couple to each other.
The subscription feature might directly check auth state by importing auth
providers instead of going through a shared core provider.

**Recommendation:** Add to AGENTS.md or ARCHITECTURE.md:

- `core/` may not import from `features/`
- `features/X/domain/` may not import from `features/Y/` (no cross-feature
  domain coupling)
- `features/X/presentation/` may import from `core/` and its own `domain/`, but
  not from `features/Y/presentation/`
- Cross-feature communication happens through `core/providers/` (e.g., auth
  state)

### 3.9 LOW: Notifications Feature is Underspecified

**Problem:** The notifications feature has the thinnest specification of all
four features. It lacks: a domain model, TDD test sequence, controller, and
clear data flow. The `notification_repository.dart` interface is listed but
never specified.

**Risk:** Implementors will have to design the notifications architecture on the
fly, likely producing inconsistent patterns compared to the other three
features.

**Recommendation:** Add a minimal specification: what methods does
`NotificationRepository` expose? (e.g., `requestPermission()`,
`getPermissionStatus()`, `setExternalUserId(String)`, `optOut()`, `optIn()`).
Add at least a controller test list matching the pattern of the other features.

---

## 4. Anti-Patterns to Avoid During Implementation

| Anti-Pattern                     | Where It Could Appear                                              | Prevention                                                                                         |
| -------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| **God Controller**               | `auth_controller.dart` orchestrating sign-in across 4 SDKs         | Extract `SessionManager` (see 3.3)                                                                 |
| **Leaky Abstraction**            | PowerSync SQL leaking into presentation layer                      | Keep raw SQL strictly in `data/` repositories; expose only typed models                            |
| **Feature Envy**                 | Notes screen checking subscription status directly                 | Access subscription state via a shared `core/` provider, not by importing `features/subscription/` |
| **Initialization Race**          | PowerSync `connect()` called before Supabase auth completes        | The plan handles this correctly; enforce with integration test (Flow 1)                            |
| **Mocking Concrete Classes**     | Tests mocking `SupabaseAuthRepository` instead of `AuthRepository` | Always mock the abstract interface, never the concrete implementation                              |
| **Generated File Checkin Drift** | `.g.dart` files getting stale or manually edited                   | Add `.g.dart` to `.gitignore` OR enforce `build_runner build` in CI before test step               |
| **Singleton Abuse**              | `Supabase.instance.client` accessed directly in features           | Always access through Riverpod providers for testability                                           |

---

## 5. Structural Improvements Summary

### Files to Add to the Plan

| File                                          | Purpose                                                    |
| --------------------------------------------- | ---------------------------------------------------------- |
| `lib/core/providers/database_provider.dart`   | Riverpod provider for PowerSync database                   |
| `lib/core/providers/supabase_provider.dart`   | Riverpod provider for Supabase client                      |
| `lib/core/providers/auth_state_provider.dart` | Shared auth state stream provider                          |
| `lib/core/session/session_manager.dart`       | Orchestrates sign-in/sign-out across all SDKs              |
| `lib/core/database/powersync_schema.dart`     | Explicit location for unified PowerSync schema             |
| `lib/core/widgets/async_value_widget.dart`    | Generic AsyncValue handler for consistent error/loading UI |
| `lib/core/widgets/error_screen.dart`          | Full-screen error for initialization failures              |

### Rules to Add to AGENTS.md

1. Dependency direction: `core/` never imports `features/`; features never
   import other features.
2. Cross-feature state is accessed via `core/providers/`, not direct feature
   imports.
3. SDK orchestration (multi-service sign-in/sign-out) goes through
   `core/session/`, not in feature repositories.
4. `.g.dart` files are generated, never hand-written.

### Tasks to Move Earlier

- Update `docs/plan.md` to replace `shadcn_ui` with Material 3 **before Phase
  1**, not in Phase 7.

---

## 6. Verdict

The plan is architecturally solid. The feature-first structure with repository
pattern, Riverpod codegen, and offline-first PowerSync data flow are well-chosen
and consistently applied. The TDD sequence is properly specified. The
initialization order is correct and well-documented.

The most significant issue is the **cross-feature coupling in the sign-out
flow** (3.3), which should be resolved with a `SessionManager` before
implementation begins. The missing `core/providers/` layer (3.1) and the
`.g.dart` file naming issue (3.4) are the next priorities.

None of the issues found are blockers. All can be addressed with additions to
the plan rather than fundamental redesign.
