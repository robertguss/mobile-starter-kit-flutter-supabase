# Flutter + Supabase Starter Kit: Flow Analysis & Gap Report

Date: 2026-03-10

---

## 1. User Flow Overview

### Flow 1: First Launch (Cold Start)

```
App opens
  -> ensureInitialized
  -> Load env vars (--dart-define-from-file)
  -> Init Sentry (wraps via appRunner)
  -> Init Supabase client
  -> Init PowerSync (connect to local SQLite)
  -> Init RevenueCat (anonymous mode until auth)
  -> runApp with ProviderScope
  -> GoRouter checks auth state
  -> No session found -> Navigate to Auth screen
```

### Flow 2: Email OTP Sign Up

```
Auth screen displayed
  -> User enters email
  -> Tap "Send OTP"
  -> Supabase sends OTP email
  -> User enters OTP code
  -> Supabase validates OTP
  -> Session created
  -> RevenueCat.logIn(userId) called
  -> PowerSync connects with authenticated user
  -> OneSignal.setExternalUserId(userId)
  -> GoRouter refreshListenable fires
  -> Navigate to Home screen
```

### Flow 3: Email OTP Sign In (Returning User)

```
Auth screen displayed
  -> User enters email
  -> Tap "Send OTP"
  -> Supabase sends OTP
  -> User enters OTP
  -> Supabase validates, restores existing session
  -> RevenueCat.logIn(userId) -- restores purchase history
  -> PowerSync reconnects, syncs pending changes
  -> OneSignal.setExternalUserId(userId)
  -> GoRouter redirect -> Home screen
```

### Flow 4: Offline Usage

```
User is authenticated, app is open
  -> Network drops
  -> PowerSync detects offline state
  -> User performs CRUD on local SQLite
  -> Changes queued in PowerSync upload queue
  -> UI remains fully functional (reads from local DB)
  -> App shows offline indicator (?)
```

### Flow 5: Coming Back Online

```
Network restored
  -> PowerSync detects connectivity
  -> Upload queue processes pending changes
  -> Server-wins conflict resolution applied
  -> Local DB updated with server state
  -> UI reflects merged state
  -> Any overwritten local changes are silently replaced (?)
```

### Flow 6: Making a Purchase (RevenueCat)

```
User taps "Subscribe" / views paywall
  -> RevenueCat paywall UI displayed
  -> User selects product
  -> Native purchase sheet (App Store / Play Store)
  -> Purchase completes
  -> RevenueCat webhook fires -> Supabase Edge Function
  -> Edge Function updates user's subscription status in DB
  -> PowerSync syncs subscription status to local DB
  -> UI reflects premium access
```

### Flow 7: Receiving Push Notifications

```
First launch or post-auth
  -> OneSignal requests notification permission (iOS)
  -> If granted: register device token
  -> If denied: app continues without push (?)
  -> Edge Function triggers OneSignal API
  -> OneSignal delivers push
  -> User taps notification
  -> App opens -> deep link routing (?)
```

### Flow 8: App Backgrounded and Resumed

```
User backgrounds app
  -> App enters paused state
  -> User resumes app
  -> Check if Supabase session is still valid
  -> Check PowerSync connection state
  -> Resync if needed
  -> Continue from where user left off
```

### Flow 9: Sign Out

```
User taps sign out
  -> Supabase.auth.signOut()
  -> RevenueCat.logOut()
  -> OneSignal.removeExternalUserId()
  -> PowerSync disconnect + clear local data (?)
  -> GoRouter refreshListenable fires
  -> Navigate to Auth screen
```

---

## 2. Flow Permutations Matrix

| Scenario          | Auth State          | Network      | Device      | Notes                                                    |
| ----------------- | ------------------- | ------------ | ----------- | -------------------------------------------------------- |
| First launch      | Unauthenticated     | Online       | iOS/Android | Happy path to auth screen                                |
| First launch      | Unauthenticated     | Offline      | iOS/Android | **UNSPECIFIED** -- Can user do anything?                 |
| Sign up           | Unauthenticated     | Online       | iOS         | OTP via email                                            |
| Sign up           | Unauthenticated     | Offline      | iOS         | **UNSPECIFIED** -- Auth requires network                 |
| Sign in returning | Has expired session | Online       | Android     | Session refresh or re-OTP?                               |
| Sign in returning | Has valid session   | Online       | iOS         | Auto-login, skip auth screen                             |
| Sign in returning | Has valid session   | Offline      | Android     | **UNSPECIFIED** -- Can user use app with cached session? |
| Offline CRUD      | Authenticated       | Offline      | Both        | Core value prop -- must work                             |
| Coming online     | Authenticated       | Reconnecting | Both        | Sync queue processes                                     |
| Purchase          | Authenticated       | Online       | iOS         | RevenueCat native flow                                   |
| Purchase          | Authenticated       | Offline      | Android     | **UNSPECIFIED** -- Purchase requires network             |
| Purchase          | Authenticated       | Flaky        | iOS         | **UNSPECIFIED** -- Partial purchase state                |
| Push received     | Authenticated       | Online       | iOS         | Notification display + tap action                        |
| Push received     | Authenticated       | Online       | Android     | Different notification handling                          |
| Push received     | App killed          | Online       | Both        | **UNSPECIFIED** -- cold start from notification          |
| Session expired   | Was authenticated   | Online       | Both        | **UNSPECIFIED** -- mid-use session expiry                |
| Session expired   | Was authenticated   | Offline      | Both        | **UNSPECIFIED** -- offline + expired                     |

---

## 3. Missing Elements & Gaps

### Category: Initialization

**Gap 3.1: Initialization failure handling**

- What happens when any init step fails? (Sentry down, Supabase unreachable,
  PowerSync SQLite corrupt)
- Impact: App could crash on launch with no recovery path
- Current ambiguity: Plan says init order but not error handling for each step

**Gap 3.2: First launch while offline**

- User clones template, builds app, opens it without network
- Impact: Supabase client init may fail, PowerSync can't do initial schema sync
- Current ambiguity: Offline-first is a key value prop but no spec for offline
  first-launch

### Category: Authentication

**Gap 3.3: OTP expiration handling**

- Supabase OTPs expire after a configurable window (default 60 seconds)
- What UI does the user see? Can they request a new OTP? Is there a cooldown?
- Impact: Users will encounter expired OTPs regularly -- this is a primary error
  path
- Current ambiguity: Only "Email OTP" is specified, no error state UI

**Gap 3.4: Network loss during OTP flow**

- User sends OTP request -> network drops -> user enters OTP -> submission fails
- Impact: User is stuck with a code they can't submit
- Current ambiguity: Not addressed

**Gap 3.5: Session persistence and refresh**

- Supabase sessions have JWT tokens with expiry. What handles token refresh?
- What happens when a user opens the app after days/weeks?
- Impact: Users could be unexpectedly logged out
- Current ambiguity: No session lifecycle management specified

**Gap 3.6: Auth state and GoRouter coordination**

- The plan mentions `refreshListenable` pattern but doesn't specify:
  - Which routes are protected vs public
  - What happens during the auth check (splash screen? loading state?)
  - Deep link handling when unauthenticated
- Impact: Race conditions between auth state resolution and routing

**Gap 3.7: Multiple device sign-in**

- User signs in on two devices. Both have local PowerSync databases.
- Impact: Sync conflicts are more likely; sign-out on one device doesn't affect
  the other
- Current ambiguity: Not addressed

### Category: Offline-First / PowerSync

**Gap 3.8: Conflict resolution user feedback**

- Server-wins means local changes can be silently overwritten
- Should the user be notified when their offline changes are overwritten?
- Impact: Users may lose work without knowing
- Current ambiguity: "server-wins" is stated as the strategy but no UX around it

**Gap 3.9: PowerSync initial sync**

- First time a user authenticates, PowerSync needs to do an initial full sync
- How long does this take? What does the user see? Is there a progress
  indicator?
- Impact: User sees empty screens until sync completes
- Current ambiguity: Not specified

**Gap 3.10: Local data on sign-out**

- When a user signs out, is the local PowerSync SQLite database cleared?
- If another user signs in on the same device, do they see the previous user's
  data?
- Impact: Critical privacy/security issue
- Current ambiguity: Not specified

**Gap 3.11: PowerSync schema versioning**

- As the template evolves, the local SQLite schema may change
- What handles schema migrations on the local device?
- Impact: App updates could break existing local databases
- Current ambiguity: Only Supabase migrations mentioned, not local schema
  evolution

### Category: Monetization (RevenueCat)

**Gap 3.12: RevenueCat anonymous-to-identified user transition**

- Research notes say RevenueCat must logIn(userId) after auth or webhooks send
  anonymous IDs
- What if logIn() fails? What if there's a race condition between purchase and
  auth?
- Impact: Purchases could be attributed to wrong/anonymous users
- Current ambiguity: Timing dependency acknowledged in research but no error
  handling specified

**Gap 3.13: Purchase restoration**

- User reinstalls app or switches devices
- RevenueCat can restore purchases, but when is this triggered?
- Impact: Users lose premium access after reinstall
- Current ambiguity: No restore flow specified

**Gap 3.14: Webhook failure handling**

- RevenueCat webhook -> Supabase Edge Function -> DB update
- What if the Edge Function fails? Is there retry logic? Idempotency?
- Impact: User pays but doesn't get premium access
- Current ambiguity: Edge Functions mentioned but no error handling or retry
  spec

**Gap 3.15: Subscription status sync**

- User's subscription expires while offline
- Local DB still shows premium. When they come online, PowerSync syncs the
  expiry.
- Is there a grace period? What happens to premium content created while
  "premium"?
- Impact: Confusing UX when subscription state changes retroactively
- Current ambiguity: Not addressed

### Category: Push Notifications (OneSignal)

**Gap 3.16: Notification permission denied flow**

- iOS requires explicit permission. If denied, what's the fallback?
- Can users re-enable later? Is there an in-app prompt explaining value before
  the system prompt?
- Impact: iOS users who deny permissions on first ask have a degraded experience
- Current ambiguity: Research mentions 7 iOS setup steps but no UX flow for
  permission handling

**Gap 3.17: Deep linking from notifications**

- User taps a notification. Where do they land in the app?
- What if they're signed out? What if the referenced content doesn't exist
  locally (offline)?
- Impact: Broken navigation from push notifications
- Current ambiguity: Not specified at all

**Gap 3.18: Notification Service Extension (iOS)**

- Research says iOS requires a Notification Service Extension
- This is an iOS build configuration concern -- needs to be in the template
- Impact: Rich notifications won't work on iOS without this
- Current ambiguity: Mentioned in research but not in implementation plan phases

### Category: Observability

**Gap 3.19: PostHog event taxonomy**

- No defined list of analytics events to track
- Impact: Every developer using the template will define their own events
  inconsistently
- Current ambiguity: PostHog is listed as a dependency but no event
  specification

**Gap 3.20: Sentry scope and context**

- How is user context attached to Sentry events? (userId, subscription tier,
  etc.)
- Impact: Debugging is harder without proper context on error reports
- Current ambiguity: Plan says "global ProviderObserver catches exceptions" but
  no scope config

### Category: Developer Experience

**Gap 3.21: Template setup automation**

- After "Use this template," what does the developer need to configure?
- Environment variables, Supabase project URL, PowerSync instance, RevenueCat
  API keys, OneSignal app ID, Sentry DSN, PostHog key
- That's 7+ services to configure before the app runs
- Impact: High friction first-run experience undermines the "batteries-included"
  promise
- Current ambiguity: No setup script, checklist, or automation mentioned

**Gap 3.22: build.yaml configuration**

- Research says build.yaml is "critical for multi-generator performance"
- Three generators: riverpod_generator, flutter_gen, slang
- Impact: Slow builds if not configured correctly; potential conflicts between
  generators
- Current ambiguity: Mentioned in research but not in any implementation phase

**Gap 3.23: Code generation workflow**

- When does a developer run build_runner? Watch mode vs one-shot?
- Are generated files committed to the repo or gitignored?
- Impact: New developers won't know when/how to run codegen
- Current ambiguity: Not specified

**Gap 3.24: Removing unwanted integrations**

- The monolith approach means "Users who don't need a specific integration can
  remove it"
- But there's no guide for how to cleanly remove, say, RevenueCat or OneSignal
- Impact: Developers who don't need all integrations face a reverse-engineering
  task
- Current ambiguity: Acknowledged but no removal guide planned

### Category: Document Inconsistencies

**Gap 3.25: shadcn_ui vs Material 3 contradiction**

- The brainstorm document explicitly says: "Material 3 with a custom theme layer
  -- NOT shadcn_ui"
- The plan.md still references shadcn_ui in multiple places:
  - Tech Stack Matrix: "UI/Design System: shadcn_ui (Flutter port)"
  - Directory Structure: "core/theme/ # shadcn_ui design system components"
  - Coding Guardrails Rule 5: "Only use shadcn_ui components"
- AGENTS.md Section 5 also says: "Use shadcn_ui components"
- Impact: **Critical** -- agents following plan.md or AGENTS.md will use the
  wrong UI system
- Current ambiguity: Direct contradiction between brainstorm (latest decision)
  and plan + AGENTS.md

**Gap 3.26: Riverpod version ambiguity**

- Research says "Riverpod 3.0 has breaking changes from 2.x"
- Neither the plan nor AGENTS.md specifies which version to use
- Impact: Using wrong version will cause significant implementation issues
- Current ambiguity: No version pinned in spec

**Gap 3.27: PowerSync version and Sync Streams**

- Research mentions "PowerSync 1.17.0 uses Rust sync client, Sync Streams
  edition 3"
- Plan doesn't mention these specifics
- Impact: Wrong PowerSync version or config could mean different sync behavior
- Current ambiguity: Version-specific behavior not captured in plan

### Category: Security

**Gap 3.28: Row-Level Security (RLS)**

- Supabase relies heavily on RLS for data access control
- No mention of RLS policies in the plan or migrations spec
- Impact: Without RLS, any authenticated user can read/write any row
- Current ambiguity: Not mentioned at all

**Gap 3.29: API key management**

- Where do Supabase anon key, service role key live?
- Are they in the JSON env files? Are those files gitignored?
- Impact: Leaked service role keys = full database access
- Current ambiguity: "JSON configuration files" mentioned but no security
  guidance

**Gap 3.30: PowerSync JWT authentication**

- PowerSync requires JWT tokens to authenticate sync connections
- How are these tokens generated and refreshed?
- Impact: Sync will fail without proper JWT handling
- Current ambiguity: Not addressed in plan

### Category: CI/CD

**Gap 3.31: CI/CD pipeline specifics**

- Phase 6 says "Generate GitHub Actions YAML workflows and Fastlane Fastfile"
- No specification of: what triggers builds, test matrix, code signing,
  deployment targets
- Impact: Generic CI/CD that doesn't actually work for production deployment
- Current ambiguity: Phase 6 is the least specified phase

**Gap 3.32: Code signing and provisioning**

- iOS requires provisioning profiles and certificates
- Android requires keystore management
- Impact: Cannot deploy without these, and they're complex to set up
- Current ambiguity: Not mentioned

---

## 4. Critical Questions Requiring Clarification

### Critical (Blocks implementation or creates security/data risks)

**Q1. How should plan.md and AGENTS.md be updated to reflect Material 3 instead
of shadcn_ui?**

- Why it matters: This is a direct contradiction. Any agent following the
  current plan.md will use shadcn_ui, which contradicts the brainstorm decision.
- Default assumption: Brainstorm is authoritative; plan.md and AGENTS.md need
  updating.

**Q2. What RLS policies should the template include?**

- Why it matters: Without RLS, the "production-ready" claim is false -- any user
  can access any data.
- Default assumption: Basic user-scoped RLS (users can only read/write their own
  rows).
- Example: A `todos` table without RLS means User A can read/delete User B's
  todos.

**Q3. What happens to local PowerSync data on sign-out?**

- Why it matters: If not cleared, the next user on the same device sees the
  previous user's data.
- Default assumption: Clear local DB on sign-out, require fresh sync on next
  sign-in.

**Q4. Which Riverpod version (2.x or 3.0) and what specific breaking changes
need to be addressed?**

- Why it matters: Riverpod 3.0 has different provider syntax, lifecycle, and
  generator output.
- Default assumption: Use 3.0 since it's specified in the task, but plan.md
  examples may need updating.

**Q5. How does PowerSync authenticate its sync connection?**

- Why it matters: PowerSync needs JWTs to sync. Without this, the entire
  offline-first architecture doesn't function.
- Default assumption: Use Supabase auth tokens passed to PowerSync connector.

### Important (Significantly affects UX or maintainability)

**Q6. What is the OTP error handling UX?**

- Why it matters: Expired OTP, wrong code, rate limiting are the most common
  auth error states.
- Default assumption: Show inline error, allow resend with 60-second cooldown
  timer.
- Example: User types OTP slowly, submits after 90 seconds -- "Code expired. Tap
  to resend."

**Q7. Should the app be usable offline before first authentication?**

- Why it matters: The offline-first value prop is undermined if the app is
  useless without network on first launch.
- Default assumption: Require network for first auth, then support offline
  thereafter.

**Q8. What does the developer setup experience look like after cloning the
template?**

- Why it matters: 7+ API keys and service configurations before first run is
  high friction.
- Default assumption: Provide a setup script or detailed README checklist.
  Consider a "demo mode" with mock services.

**Q9. What happens when the RevenueCat webhook Edge Function fails?**

- Why it matters: User has paid but the DB doesn't reflect it. This is a support
  nightmare.
- Default assumption: RevenueCat retries webhooks. Edge Function should be
  idempotent with proper error responses.

**Q10. How does notification deep linking work?**

- Why it matters: Tapping a notification that leads nowhere (or crashes) is a
  terrible user experience.
- Default assumption: Notifications include a route path; GoRouter handles it.
  If unauthenticated, queue the deep link until after sign-in.

### Nice-to-Have (Improves clarity but has reasonable defaults)

**Q11. Should the user be notified when server-wins conflict resolution
overwrites their local changes?**

- Why it matters: Silent data loss is confusing, but notifications for every
  sync conflict could be noisy.
- Default assumption: No notification for v1, but document the behavior clearly.

**Q12. What analytics events should the template pre-define?**

- Why it matters: A bare PostHog integration without any events isn't useful as
  a starter template.
- Default assumption: Include basic events: app_open, sign_in, sign_out,
  purchase_started, purchase_completed, screen_view.

**Q13. Are generated files (riverpod, flutter_gen, slang) committed or
gitignored?**

- Why it matters: Affects build reproducibility and git diff noise.
- Default assumption: Commit generated files so the app works immediately after
  clone without running build_runner.

**Q14. What is the minimum example feature to demonstrate the architecture?**

- Why it matters: A starter kit with auth but no example feature doesn't show
  users how to build with the architecture.
- Default assumption: A simple "notes" or "todos" feature demonstrating full
  offline CRUD.

---

## 5. Recommended Next Steps

1. **Resolve the shadcn_ui vs Material 3 contradiction immediately.** Update
   plan.md Section 3 (Tech Stack Matrix), Section 5 (Directory Structure
   comment), Section 6 Rule 5, and AGENTS.md Section 5 to reflect the Material 3
   decision from the brainstorm.

2. **Add an "Error States & Edge Cases" section to plan.md** covering at
   minimum: init failures, OTP expiration, network loss during auth, sync
   conflicts UX, purchase failures, and notification permission denial.

3. **Specify the auth session lifecycle**: token refresh, session expiry
   handling, sign-out cleanup (especially PowerSync local data clearing).

4. **Add RLS policies to Phase 3 (Data Layer)**: at minimum, user-scoped
   read/write policies for every table.

5. **Pin dependency versions** for Riverpod (3.x), PowerSync (1.17.x), and any
   other packages with known breaking changes.

6. **Design the developer setup experience**: either a setup script, Makefile,
   or comprehensive checklist that walks through all 7+ service configurations.

7. **Add a build.yaml specification** to Phase 1 or Phase 2 covering the three
   generators (riverpod_generator, flutter_gen, slang) and their build ordering.

8. **Specify Phase 6 (CI/CD) in more detail**: trigger conditions, test matrix
   (unit + widget + integration), code signing approach, and deployment targets.

9. **Add a "Template Customization Guide"** section explaining how to remove
   individual integrations cleanly (e.g., "Removing RevenueCat: delete these
   files, remove these providers, update these routes").

10. **Include a sample feature** (e.g., "notes" or "todos") that demonstrates
    the full TDD cycle with offline CRUD, serving as both a working example and
    documentation.
