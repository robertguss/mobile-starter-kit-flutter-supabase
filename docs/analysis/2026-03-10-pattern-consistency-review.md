# Pattern Consistency Review: Flutter & Supabase Starter Kit Plan

**Date:** 2026-03-10 **Scope:** Design patterns, anti-patterns, naming
conventions, and duplication across the implementation plan.

---

## 1. Repository Pattern Consistency Across Features

### Current State (4 features compared)

| Feature       | domain/ abstract        | domain/ model      | data/ concrete                     | presentation/ controller  | presentation/ screens   |
| ------------- | ----------------------- | ------------------ | ---------------------------------- | ------------------------- | ----------------------- |
| Auth          | auth_repository         | user_model         | supabase_auth_repository           | auth_controller.g         | login, otp_verify       |
| Notes         | note_repository         | note_model         | powersync_note_repository          | notes_controller.g        | notes_list, note_detail |
| Subscription  | subscription_repository | subscription_model | revenuecat_subscription_repository | subscription_controller.g | paywall                 |
| Notifications | notification_repository | (none)             | onesignal_notification_repository  | (none)                    | notification_settings   |

### Issues Found

**ISSUE 1: Notifications feature is structurally incomplete.**

- Missing `notification_model.dart` in domain/. Even if the feature is thin,
  every feature in a starter kit should demonstrate the full pattern. Users will
  copy this structure. A `NotificationPreferences` model (permission status,
  opted-in categories) would complete the pattern.
- Missing a controller (no `.g.dart` file listed). The settings screen needs
  state management for permission status, toggle states, etc. Without a
  controller, this feature breaks the "every feature has
  domain/data/presentation with controller" convention the other three features
  establish.

**Recommendation:** Add `notification_model.dart` and
`notification_controller.dart` to notifications. The starter kit's value is
pattern consistency -- every feature must be a complete example of the
architecture.

**ISSUE 2: Auth feature has cross-cutting side effects buried in data/.**

- `supabase_auth_repository.dart` calls `Purchases.logIn(user.id)` and
  `OneSignal.login(user.id)` after auth success. This creates tight coupling
  between the auth data layer and two unrelated SDKs.
- This violates the repository pattern's purpose (single data source
  abstraction) and makes the auth repository untestable in isolation without
  mocking RevenueCat and OneSignal.

**Recommendation:** Move these side effects to the auth controller or to a
dedicated `AuthEventHandler` / listener that reacts to `authStateChanges`. The
repository should only handle Supabase auth operations. The controller or a
top-level listener is the correct place to orchestrate cross-feature reactions
to auth events.

**ISSUE 3: Inconsistent singular vs. plural naming in controllers.**

- Auth: `auth_controller` (singular feature name)
- Notes: `notes_controller` (plural feature name)
- Subscription: `subscription_controller` (singular)

**Recommendation:** Pick one convention and apply it everywhere. Since the
feature directories use singular nouns (`auth`, `subscription`) except `notes`,
standardize to singular: `note_controller.dart`, `note_list_screen.dart`.
Alternatively, if the directory stays `notes/`, keep `notes_controller` but
document the convention: "controller name matches directory name."

---

## 2. Naming Convention Analysis

### File Naming

**Pattern observed:** `<qualifier>_<entity>_<type>.dart`

- Good: `supabase_auth_repository.dart`, `powersync_note_repository.dart`,
  `revenuecat_subscription_repository.dart`
- The prefix names the concrete implementation source. This is a strong,
  consistent pattern.

**Issue:** Screen naming is inconsistent:

- `login_screen.dart` (no feature prefix)
- `otp_verify_screen.dart` (action-based, no feature prefix)
- `notes_list_screen.dart` (entity + view-type)
- `note_detail_screen.dart` (entity + view-type)
- `paywall_screen.dart` (domain concept, no feature prefix)
- `notification_settings_screen.dart` (feature + view-type)

**Recommendation:** Since screens live inside feature directories, the feature
prefix is redundant in the filename. Standardize to `<purpose>_screen.dart`:

- `auth/presentation/login_screen.dart` -- good as-is
- `auth/presentation/otp_verify_screen.dart` -- good as-is
- `notes/presentation/list_screen.dart` or keep `notes_list_screen.dart`
  (acceptable since it disambiguates)
- `subscription/presentation/paywall_screen.dart` -- good as-is

The current approach is reasonable. Just document the convention: "Screen files
use descriptive names; feature directory provides namespace."

### Class Naming

**Pattern observed (repositories):**

- Abstract: `AuthRepository`, `NoteRepository`, `SubscriptionRepository`,
  `NotificationRepository`
- Concrete: `SupabaseAuthRepository`, `PowerSyncNoteRepository`,
  `RevenueCatSubscriptionRepository`, `OneSignalNotificationRepository`

This is excellent -- concrete classes are prefixed with their backing service.
No changes needed.

### Route Naming

**Routes listed:** `/login`, `/otp-verify`, `/notes`, `/note/:id`, `/settings`,
`/paywall`

**Issue:** Inconsistent use of hyphens vs. feature grouping:

- `/otp-verify` uses a hyphen (kebab-case action)
- `/note/:id` is singular
- `/notes` is plural
- No route grouping by feature (e.g., no `/auth/login`, `/auth/otp-verify`)

**Recommendation:** For a starter kit, flat routes are fine for simplicity. But
standardize plurality:

- `/notes` (list) and `/notes/:id` (detail) -- both plural, RESTful convention
- Or `/note` and `/note/:id` -- both singular

Pick one. RESTful plural is the stronger convention: `/notes`, `/notes/:id`.

Also consider named routes as constants. The plan doesn't mention this, but
AGENTS.md says keep route definitions centralized. Add a `RouteNames` or
`AppRoutes` class with static constants:

```dart
abstract class AppRoutes {
  static const login = '/login';
  static const otpVerify = '/otp-verify';
  static const notes = '/notes';
  static String noteDetail(String id) => '/notes/$id';
  static const settings = '/settings';
  static const paywall = '/paywall';
}
```

This prevents stringly-typed route references scattered across the codebase and
gives AI agents a single source of truth for navigation targets.

---

## 3. TDD Workflow Consistency Across Phases

### AGENTS.md prescribes this sequence:

1. Abstract interface in `domain/`
2. Mock using `mocktail` in `test/.../domain/`
3. Unit tests for state and logic
4. Concrete class in `data/`
5. UI in `presentation/`

### Phase-by-phase compliance:

**Phase 4 (Auth) -- COMPLIANT with enhancement.** Follows the sequence exactly:
domain first, mocks, tests, implementation, presentation. The plan explicitly
labels the TDD sequence and lists tests before implementation. Good.

**Phase 5 (Notes) -- COMPLIANT.** Same sequence. Tests are listed before
implementation. The plan includes data layer tests
(`powersync_note_repository_test.dart`), which is good.

**Phase 6 (Subscriptions) -- PARTIALLY COMPLIANT.** The task list follows the
order (domain, mock, test, data, presentation), but:

- No `data/revenuecat_subscription_repository_test.dart` is listed in the test
  directory tree. Auth and Notes both have data layer tests. Subscriptions
  should too.
- The paywall screen has no widget test listed (`paywall_screen_test.dart`).
  Auth and Notes both have screen-level widget tests.

**Phase 6 (Notifications) -- NOT COMPLIANT.**

- No mock listed (`mock_notification_repository.dart` is absent from the test
  tree)
- No controller test listed
- No widget test for `notification_settings_screen.dart`
- The TDD sequence appears to be skipped entirely for this feature

**Recommendation:** Add the following to the plan:

```
test/features/subscription/
    data/
        revenuecat_subscription_repository_test.dart    # MISSING
    presentation/
        paywall_screen_test.dart                         # MISSING

test/features/notifications/
    domain/
        mock_notification_repository.dart                # MISSING
    presentation/
        notification_controller_test.dart                # MISSING
        notification_settings_screen_test.dart           # MISSING
```

Every feature in a starter kit must demonstrate the full TDD workflow. If
notifications is intentionally thin, document why and still provide at least one
test per layer as a reference.

---

## 4. Notes Feature as Architecture Reference

### Does Notes demonstrate all patterns users need?

**What it covers well:**

- Full domain/data/presentation layer separation
- PowerSync offline-first CRUD (the primary data pattern)
- Riverpod controller with `@riverpod` codegen
- `AsyncValue` state management
- Stream-based reactive data (`watchNotes()`)
- Widget composition (`widgets/` subdirectory with `note_card.dart`,
  `sync_status_indicator.dart`)
- List and detail screens (common CRUD UI pair)

**What it does NOT demonstrate (gaps):**

**GAP 1: No example of feature-to-feature communication.** Notes is
self-contained. Users will need to know how one feature reads state from another
(e.g., checking subscription status before allowing note creation). The plan
should include at least one cross-feature provider read in Notes to demonstrate
this pattern.

**Recommendation:** Add a `subscriptionProvider` check in the notes controller
that limits free-tier users to N notes. This is a natural paywall integration
point and demonstrates cross-feature Riverpod usage.

**GAP 2: No form validation pattern.** Notes has create/edit but the plan
doesn't mention form validation. Auth has email validation, but that's a simple
format check. A note form with title required + body length limit would
demonstrate the validation pattern users will replicate.

**Recommendation:** Add form validation to `note_detail_screen.dart` and include
a test for it.

**GAP 3: No delete confirmation / destructive action pattern.** `deleteNote`
exists in the repository but the plan doesn't show how the UI handles it
(confirmation dialog, optimistic removal, undo snackbar). This is a pattern
every CRUD feature needs.

**Recommendation:** Document the delete UX pattern in the Notes feature:
confirmation dialog, optimistic delete with undo snackbar, or swipe-to-dismiss
with undo.

**GAP 4: No search/filter pattern.** `getNotes()` returns all notes. Most list
screens need search or filter. Even a simple local filter on the `watchNotes()`
stream would demonstrate the pattern.

**Recommendation:** Add a `searchNotes(String query)` to the repository
interface or show filtering at the controller level. This is optional but
valuable for a reference feature.

**GAP 5: No error state UI pattern in the screen.** Tests mention error states,
but the plan doesn't describe what the error UI looks like in Notes. Auth
mentions snackbars. Notes should explicitly demonstrate error state rendering
(empty state, error state, loading state -- the "tri-state" pattern).

**Recommendation:** Explicitly call out that `notes_list_screen.dart`
demonstrates the `AsyncValue.when(data:, loading:, error:)` pattern as a
reference for all future list screens.

---

## 5. Riverpod Provider Patterns with Codegen

### What the plan specifies:

- `@riverpod` annotations on controllers
- `.g.dart` generated files in presentation/
- `AsyncValue` for all data fetching
- `ConsumerWidget` preferred over `StatefulWidget`
- `ProviderObserver` for Sentry error reporting
- `databaseProvider.overrideWithValue(db)` for PowerSync injection

### Issues Found

**ISSUE 1: Repository provider registration is unspecified.** The plan shows
concrete repositories in `data/` and abstract interfaces in `domain/`, but never
specifies how repositories are provided to controllers via Riverpod. This is a
critical architectural decision that's missing.

**Recommendation:** Explicitly define the repository provider pattern. Two
approaches:

Option A -- Provider in each feature's domain/ directory:

```dart
// lib/features/notes/domain/note_repository.dart
@riverpod
NoteRepository noteRepository(Ref ref) {
  return PowerSyncNoteRepository(db: ref.watch(databaseProvider));
}
```

Option B -- Provider in each feature's data/ directory alongside the concrete
class:

```dart
// lib/features/notes/data/powersync_note_repository.dart
@riverpod
NoteRepository noteRepository(Ref ref) {
  return PowerSyncNoteRepository(db: ref.watch(databaseProvider));
}
```

Option A is better for a starter kit because it keeps the provider next to the
interface, making it easy to swap implementations. Document this convention
explicitly.

**ISSUE 2: No convention for provider file organization.** Should each
controller be in its own file with its own `.g.dart`? Should all providers for a
feature be in one file? The plan implies one controller per feature but doesn't
state the rule.

**Recommendation:** One controller per file, each generating its own `.g.dart`.
State this explicitly:

- `notes_controller.dart` -> `notes_controller.g.dart` (controller + its
  providers)
- `note_repository.dart` -> contains the repository provider (if using codegen
  for the provider)

**ISSUE 3: The `build.yaml` scoping only targets `presentation/` for
riverpod_generator.** The plan says: "Scope `riverpod_generator` to
`lib/features/**/presentation/`". But if repository providers use `@riverpod`
annotations (as recommended above), they live in `domain/` or `data/`, which
would be outside the generator scope.

**Recommendation:** Either:

- Expand the `generate_for` scope to include `domain/` directories, or
- Use manual providers (not codegen) for repository registration and reserve
  `@riverpod` for controllers only. Document which layer uses codegen and which
  doesn't.

---

## 6. GoRouter Route Patterns

### What the plan specifies:

- Centralized in `lib/core/router/app_router.dart`
- `refreshListenable` pattern for auth state
- Global redirect: unauthenticated -> `/login`, authenticated -> `/notes`
- No `go_router_builder` (no generated routes)

### Issues Found

**ISSUE 1: No ShellRoute pattern demonstrated.** The plan has `/notes`,
`/settings`, `/paywall` as top-level routes. In a real app, these would share a
scaffold with bottom navigation. The plan doesn't mention `ShellRoute` or
`StatefulShellRoute`, which is how GoRouter handles persistent navigation
shells.

**Recommendation:** Add a `ShellRoute` wrapping the authenticated routes
(`/notes`, `/settings`, `/paywall`) with a `BottomNavigationBar` or
`NavigationBar`. This is one of the most common GoRouter patterns users will
need and it's currently missing.

**ISSUE 2: No nested route pattern demonstrated.** All routes are flat:
`/notes`, `/note/:id`, `/settings`, `/paywall`. There's no nesting (e.g.,
`/notes/:id` as a child of `/notes`). Nested routes with `ShellRoute` are the
standard GoRouter pattern for preserving parent state.

**Recommendation:** Structure routes as:

```
ShellRoute (authenticated shell with bottom nav)
  /notes
    /notes/:id (child route, pushes on top of list)
  /settings
  /paywall
```

**ISSUE 3: No route guard pattern beyond auth redirect.** The plan only shows
auth-based redirection. There's no example of a feature-specific guard (e.g.,
"redirect to paywall if not subscribed and trying to access premium feature").
Since the starter kit has subscriptions, this is a natural place to demonstrate
the pattern.

**Recommendation:** Add a subscription guard example, even if it's commented out
or behind a flag. Users will need to know how to add route-level guards beyond
auth.

---

## 7. Test File Organization Consistency

### Current test tree structure:

```
test/
  core/
    database/powersync_connector_test.dart
    router/app_router_test.dart
  features/
    auth/
      domain/mock_auth_repository.dart
      data/supabase_auth_repository_test.dart
      presentation/
        auth_controller_test.dart
        login_screen_test.dart
        otp_verify_screen_test.dart
    notes/
      domain/mock_note_repository.dart
      data/powersync_note_repository_test.dart
      presentation/
        notes_controller_test.dart
        notes_list_screen_test.dart          # no note_detail_screen_test.dart
    subscription/
      domain/mock_subscription_repository.dart
      presentation/
        subscription_controller_test.dart    # no data/ test, no screen test
    notifications/                            # ENTIRELY MISSING from test tree
  helpers/
    test_helpers.dart
```

### Issues Found

**ISSUE 1: Missing test files create an inconsistent pattern.**

| Test Type       | Auth    | Notes   | Subscription | Notifications |
| --------------- | ------- | ------- | ------------ | ------------- |
| Mock            | Yes     | Yes     | Yes          | NO            |
| Data test       | Yes     | Yes     | NO           | NO            |
| Controller test | Yes     | Yes     | Yes          | NO            |
| Screen test(s)  | Yes (2) | Yes (1) | NO           | NO            |

For a starter kit, every feature should have the same test structure. Users will
use it as a template.

**ISSUE 2: `note_detail_screen_test.dart` is missing.** Auth has tests for both
screens (login + otp_verify). Notes has two screens (list + detail) but only
tests for the list. The detail screen has auto-save behavior which is complex
enough to warrant testing.

**ISSUE 3: Mocks live in `test/.../domain/` but are not test files.** Files like
`mock_auth_repository.dart` are test utilities, not tests themselves. Placing
them in `domain/` mirrors the source structure but could cause confusion.
Consider whether a `test/features/<feature>/mocks/` or `test/helpers/mocks/`
directory would be clearer.

**Recommendation:** Either convention works, but document it explicitly. The
current approach (mock in the same layer as the interface it mocks) has the
advantage of co-location. Just ensure the naming convention is consistent:
`mock_<entity>_repository.dart`.

**ISSUE 4: No integration test directory.** The plan lists 5 integration test
scenarios in the "Integration Test Scenarios" section but has no
`integration_test/` directory in the file tree. Flutter integration tests
conventionally live in `integration_test/`.

**Recommendation:** Add to the file tree:

```
integration_test/
  auth_flow_test.dart
  offline_crud_test.dart
  subscription_flow_test.dart
```

Even if integration tests are out of scope for initial implementation, the
directory and at least one skeleton test should exist as a pattern reference.

---

## 8. AGENTS.md Conflicts with Plan

**CONFLICT 1: UI framework mismatch.** AGENTS.md Section 5 says: "Use
`shadcn_ui` components (e.g., `ShadButton`, `ShadInput`) for all UI elements."
The plan says: Material 3 with custom theme (app_theme.dart, app_colors.dart,
app_typography.dart). Phase 7 includes: "Update AGENTS.md -- replace `shadcn_ui`
references with Material 3 + custom theme."

This is acknowledged in the plan but it's deferred to Phase 7 (the last phase).
Any AI agent executing Phases 2-6 will read AGENTS.md and use shadcn_ui
components.

**Recommendation:** Update AGENTS.md FIRST, in Phase 1 or Phase 2, before any UI
work begins. An agent following AGENTS.md during Phase 4 (Auth UI) will build
with shadcn_ui, which contradicts the plan.

**CONFLICT 2: No Riverpod codegen convention in AGENTS.md.** AGENTS.md says "use
`@riverpod` annotations" but doesn't specify:

- Where repository providers live
- Whether to use `@riverpod` on repositories or only controllers
- The `build.yaml` scoping rules

**Recommendation:** Add a "Riverpod Provider Conventions" subsection to
AGENTS.md specifying these decisions before Phase 4 begins.

---

## 9. Anti-Pattern Indicators

**ANTI-PATTERN 1: God initialization in main.dart.** `main.dart` initializes 6
SDKs sequentially. While the initialization order is documented and justified,
this will grow unwieldy as services are added. Consider an `AppInitializer`
class that encapsulates the sequence and makes it testable.

**ANTI-PATTERN 2: Sign-out as a distributed concern.** Sign-out requires:
PowerSync.disconnectAndClear() -> Purchases.logOut() -> OneSignal.logout() ->
Supabase.auth.signOut() -> Router redirect. This is spread across the
interaction graph but the plan puts it in `supabase_auth_repository.dart`. The
auth repository should not know about PowerSync, RevenueCat, or OneSignal.

**Recommendation:** Create a `SignOutUseCase` or handle sign-out orchestration
in the auth controller (or a dedicated listener), not the repository. The
repository's `signOut()` should only call `supabase.auth.signOut()`. Cleanup of
other services belongs at a higher orchestration level.

**ANTI-PATTERN 3: Implicit coupling through initialization order.** PowerSync
depends on Supabase auth for credentials. RevenueCat needs userId after auth.
OneSignal needs userId after auth. These dependencies are implicit
(order-of-execution) rather than explicit (dependency injection). The
`ProviderScope` overrides help, but the `main.dart` init sequence should be
documented as a contract, not just a code comment.

---

## 10. Summary of Recommendations (Priority Order)

### Must Fix (architectural consistency)

1. **Update AGENTS.md in Phase 1, not Phase 7.** The shadcn_ui vs Material 3
   conflict will cause every AI agent to build wrong UI during Phases 2-6.
2. **Add missing test files for Subscription and Notifications.** Every feature
   needs mock + data test + controller test + screen test to serve as a TDD
   reference.
3. **Complete the Notifications feature structure.** Add
   `notification_model.dart` and `notification_controller.dart` to demonstrate
   the full pattern.
4. **Define the repository provider registration pattern explicitly.** Where
   does the Riverpod provider for each repository live? This is a gap in both
   the plan and AGENTS.md.
5. **Move auth side effects (RevenueCat, OneSignal) out of the auth
   repository.** Use a listener or controller-level orchestration instead.

### Should Fix (convention consistency)

6. **Standardize singular/plural naming.** Pick `note_controller` or
   `notes_controller` and apply consistently.
7. **Standardize route naming.** Use `/notes/:id` (plural, RESTful) instead of
   `/note/:id`.
8. **Add named route constants.** Prevent stringly-typed navigation references.
9. **Add `note_detail_screen_test.dart`.** Both screens in Notes should have
   tests since this is the reference feature.
10. **Fix `build.yaml` scoping for `riverpod_generator`.** If repository
    providers use `@riverpod`, the scope must include `domain/` or `data/`, not
    just `presentation/`.

### Nice to Have (completeness of reference patterns)

11. **Add `ShellRoute` pattern** for bottom navigation in authenticated routes.
12. **Add cross-feature provider read** in Notes (subscription check) as a
    reference pattern.
13. **Add `integration_test/` directory** with at least one skeleton test.
14. **Add form validation pattern** to note detail screen.
15. **Add delete confirmation UX pattern** to Notes.
16. **Consider `AppInitializer` class** to encapsulate main.dart SDK
    initialization sequence.
