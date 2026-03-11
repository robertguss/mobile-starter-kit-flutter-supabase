# Security Review: Flutter & Supabase Production Starter Kit

**Date:** 2026-03-10 **Reviewer:** Security Sentinel (Claude Opus 4.6)
**Document Reviewed:**
docs/plans/2026-03-10-feat-flutter-supabase-starter-kit-plan.md **Severity
Scale:** CRITICAL / HIGH / MEDIUM / LOW / INFO

---

## Executive Summary

The plan is architecturally sound with good security instincts (RLS, local data
clearing, webhook signature verification). However, there are **3 critical**,
**5 high**, **4 medium**, and **3 low** severity gaps that must be addressed
before this template ships to production users. The most dangerous gaps are:
config JSON files containing secrets committed to git, missing OTP brute-force
protection on the client, and insufficient webhook validation in the Edge
Function spec.

---

## 1. Supabase Email OTP Auth Flow

### [HIGH] OTP Brute-Force / Rate Limiting on Client

**Issue:** The plan mentions "max 3 attempts, then re-send" but this is purely
client-side enforcement. An attacker bypassing the UI can submit unlimited OTP
guesses directly against the Supabase API.

**Recommendation:**

- Supabase enforces server-side rate limits on `verifyOTP`, but you must
  configure them explicitly in the Supabase dashboard (Auth > Rate Limits). Set
  `RATE_LIMIT_OTP_VERIFY` to a low value (e.g., 5 per hour per IP).
- Add exponential backoff on the client as defense-in-depth, not as the sole
  protection.
- Document the required Supabase Auth rate limit configuration in README setup
  instructions.

### [MEDIUM] Session Token Storage

**Issue:** The plan does not specify where Supabase auth tokens (access token,
refresh token) are stored on-device. Flutter's `supabase_flutter` defaults to
`SharedPreferences` / `NSUserDefaults`, which are **not encrypted at rest**.

**Recommendation:**

- Use `flutter_secure_storage` as the persistence layer for Supabase auth
  tokens. Supabase Flutter supports custom `localStorage` implementations:
  ```dart
  await Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(), // custom impl using flutter_secure_storage
    ),
  );
  ```
- Add `flutter_secure_storage` to the dependency list in Phase 1.

### [MEDIUM] Auth State Change Listener Race Condition

**Issue:** The plan calls `Purchases.logIn(userId)` and
`OneSignal.login(userId)` "after successful auth" but does not specify whether
this happens in the `verifyOtp` success callback or the `authStateChanges`
stream listener. If it is only in the callback, session restoration on app
restart will skip these calls.

**Recommendation:**

- Wire RevenueCat and OneSignal login to the `authStateChanges` stream listener,
  not to the OTP verification callback. This ensures re-identification on every
  session restoration (app cold start with existing token).
- On sign-out, ensure `Purchases.logOut()` and `OneSignal.logout()` are also
  triggered from the stream listener to avoid orphaned identity states.

### [LOW] OTP Channel Downgrade

**Issue:** Email OTP is the sole auth method. If a user's email is compromised,
account takeover is trivial. This is acceptable for a starter kit, but should be
documented.

**Recommendation:**

- Add a "Security Considerations" section to README noting that Email OTP alone
  provides single-factor authentication.
- Document the path to adding MFA or social login for production apps that
  require stronger auth.

---

## 2. Row-Level Security (RLS) Policies

### [HIGH] Missing RLS Policy Specificity

**Issue:** The plan says "users can only CRUD their own notes
(`auth.uid() = user_id`)" but does not specify separate policies per operation
(SELECT, INSERT, UPDATE, DELETE). A single permissive policy can mask
authorization gaps.

**Recommendation:** Define explicit per-operation policies in the migration:

```sql
-- notes table
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own notes"
  ON notes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own notes"
  ON notes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own notes"
  ON notes FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notes"
  ON notes FOR DELETE
  USING (auth.uid() = user_id);
```

The `WITH CHECK` on INSERT is critical -- without it, a user could insert notes
with another user's `user_id`.

### [HIGH] Missing `user_id` Default on INSERT

**Issue:** The plan defines `user_id uuid references auth.users` but does not
set a default. This means the client must supply `user_id`, and a malicious
client could supply a different user's UUID.

**Recommendation:**

- Set `user_id` default to `auth.uid()` in the column definition:
  ```sql
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id)
  ```
- Combine with the RLS `WITH CHECK` policy above so even if a client sends a
  foreign `user_id`, the policy rejects it.

### [MEDIUM] Subscriptions Table -- Write Access

**Issue:** The plan says "users can only read their own subscription" but the
RevenueCat webhook Edge Function needs to INSERT/UPDATE subscriptions. The plan
does not specify a service-role bypass or a separate policy for the Edge
Function.

**Recommendation:**

- Edge Functions using `createClient` with the `service_role` key bypass RLS by
  default. Document this explicitly.
- Add a comment in the migration clarifying: "Write access is restricted to the
  service role (Edge Functions only). No client-side INSERT/UPDATE policies
  exist intentionally."
- Ensure the `subscriptions` table has NO INSERT/UPDATE/DELETE policies for the
  `authenticated` role.

### [INFO] Missing `updated_at` Trigger

**Issue:** `updated_at timestamptz default now()` only sets the value on INSERT.
Updates will leave `updated_at` stale unless a trigger is added.

**Recommendation:** Add a trigger in the migration:

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
```

---

## 3. PowerSync JWT Token Generation and Refresh

### [HIGH] JWT Exposure via `fetchCredentials()`

**Issue:** The plan states `fetchCredentials()` gets a JWT from
`Supabase.auth.currentSession.accessToken`. This JWT is the Supabase access
token, which grants full authenticated API access. If PowerSync's infrastructure
is compromised, this token could be used to call Supabase APIs directly.

**Recommendation:**

- Evaluate whether PowerSync supports scoped tokens or a dedicated JWT endpoint.
  If the Supabase access token must be used, ensure:
  1. Token lifetime is short (default 1 hour in Supabase -- do not extend it).
  2. The PowerSync connector's `fetchCredentials()` checks token expiry and
     calls `supabase.auth.refreshSession()` if the token is within 60 seconds of
     expiry.
  3. Document this trust boundary in the architecture docs.

### [MEDIUM] Token Refresh Failure Handling

**Issue:** The plan mentions "Session expiry: Auth token expires -> PowerSync
connector refreshes JWT -> sync continues" but does not specify the failure path
when the refresh token itself has expired (default 1 week in Supabase).

**Recommendation:**

- In `fetchCredentials()`, catch refresh failures and trigger a full sign-out +
  redirect to login:
  ```dart
  Future<PowerSyncCredentials> fetchCredentials() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw CredentialsException('No active session');
    }
    if (session.isExpired) {
      final response = await supabase.auth.refreshSession();
      if (response.session == null) {
        // Refresh token expired -- force re-authentication
        await signOut();
        throw CredentialsException('Session expired, please sign in again');
      }
    }
    return PowerSyncCredentials(
      endpoint: env.powersyncUrl,
      token: supabase.auth.currentSession!.accessToken,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        supabase.auth.currentSession!.expiresAt! * 1000,
      ),
    );
  }
  ```

---

## 4. RevenueCat Webhook Signature Verification

### [CRITICAL] Incomplete Webhook Validation Spec

**Issue:** The plan says "Verify webhook signature" but does not specify:

1. Which header contains the signature (`Authorization` bearer token for
   RevenueCat).
2. How to compare -- RevenueCat uses a shared secret in the `Authorization`
   header, NOT HMAC signing.
3. Timing-safe comparison to prevent timing attacks.

**Recommendation:** Specify the full validation logic in the Edge Function:

```typescript
import { timingSafeEqual } from "node:crypto";

const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")!;

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401 });
  }

  const token = authHeader.replace("Bearer ", "");
  const expected = new TextEncoder().encode(WEBHOOK_SECRET);
  const received = new TextEncoder().encode(token);

  if (
    expected.length !== received.length ||
    !timingSafeEqual(expected, received)
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Process webhook...
});
```

### [CRITICAL] Missing `app_user_id` Validation Detail

**Issue:** The plan correctly flags "Validate that `app_user_id` is a valid
Supabase UUID (not `$RCAnonymousID`)" but does not specify what to do when
validation fails.

**Recommendation:**

- **Reject the webhook with a 400 status** if `app_user_id` starts with
  `$RCAnonymousID` or is not a valid UUID v4. Do NOT silently drop it
  (RevenueCat will retry on 5xx but not on 4xx).
- Log the rejection to Sentry for monitoring -- this indicates a client-side
  `Purchases.logIn()` failure.
- Add a specific error response body so debugging is possible:
  ```typescript
  if (!isValidUUID(event.app_user_id)) {
    console.error(`Invalid app_user_id: ${event.app_user_id}`);
    return new Response(JSON.stringify({ error: "Invalid app_user_id" }), {
      status: 400,
    });
  }
  ```

### [HIGH] Webhook Replay Protection

**Issue:** No mention of idempotency or replay protection. A replayed webhook
could re-process a subscription event.

**Recommendation:**

- Store a unique event ID (RevenueCat sends `id` in the payload) in the
  `subscriptions` table or a separate `webhook_events` table.
- Before processing, check if the event ID has already been processed. If so,
  return 200 (acknowledge) without re-processing.
- This also protects against RevenueCat's automatic retries causing duplicate
  processing.

---

## 5. Environment Config Handling (Secrets in JSON Files)

### [CRITICAL] Config Files with Secrets in Source Control

**Issue:** The plan creates `config_dev.json`, `config_staging.json`, and
`config_prod.json` in a `config/` directory. The `.gitignore` mentions
`config_prod.json` but NOT `config_staging.json`. Furthermore, even
`config_dev.json` will contain real API keys for development services (Sentry
DSN, PostHog API key, etc.) and will be committed to the PUBLIC template
repository.

**Recommendation:**

1. **NEVER commit any config file with real secrets.** Instead:
   - Create `config/config_example.json` with placeholder values (committed).
   - Add ALL `config_*.json` files (except `config_example.json`) to
     `.gitignore`:
     ```
     config/config_dev.json
     config/config_staging.json
     config/config_prod.json
     ```
   - Document in README: "Copy `config_example.json` to `config_dev.json` and
     fill in your values."

2. **For CI/CD:** Use GitHub Actions secrets to generate the config file at
   build time:

   ```yaml
   - name: Create config file
     run: |
       echo '${{ secrets.CONFIG_PROD_JSON }}' > config/config_prod.json
   ```

3. **Add a pre-commit hook** (or CI check) that rejects commits containing files
   matching `config/config_*.json` (excluding `config_example.json`).

### [MEDIUM] Supabase Anon Key Exposure

**Issue:** The `supabaseAnonKey` is included in client-side config. While
Supabase anon keys are designed to be public (they are used with RLS), many
developers do not understand this and may confuse the anon key with the service
role key.

**Recommendation:**

- Add a prominent comment in `config_example.json`:
  ```json
  {
    "SUPABASE_ANON_KEY": "your-anon-key-here (safe for client-side, NOT the service_role key)",
    "SUPABASE_SERVICE_ROLE_KEY": "DO NOT PUT THIS IN CLIENT CONFIG -- Edge Functions only"
  }
  ```
- Ensure the service role key is NEVER in any client-side config file. It should
  only exist in Supabase Edge Function environment variables.

---

## 6. Edge Function Security (TypeScript)

### [HIGH] Missing CORS Configuration

**Issue:** The Edge Functions (`revenuecat-webhook`, `onesignal-trigger`) have
no mention of CORS headers or origin restrictions.

**Recommendation:**

- The RevenueCat webhook should NOT have permissive CORS -- it is
  server-to-server. Reject requests with `Origin` headers:
  ```typescript
  if (req.headers.get("Origin")) {
    return new Response("Forbidden", { status: 403 });
  }
  ```
- The OneSignal trigger (if called from the client) needs explicit origin
  whitelisting. Otherwise, make it server-to-server only.

### [MEDIUM] Edge Function Error Leakage

**Issue:** No specification for error handling in Edge Functions. Unhandled
exceptions in Deno will return stack traces to the caller.

**Recommendation:**

- Wrap all Edge Function logic in try/catch with generic error responses:
  ```typescript
  try {
    // ... business logic
  } catch (error) {
    console.error("Internal error:", error); // Logged server-side
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
    });
  }
  ```
- Never return `error.message` or `error.stack` to the client.

---

## 7. OneSignal Push Notification Security

### [LOW] OneSignal Player ID / External ID Spoofing

**Issue:** `OneSignal.login(userId)` associates the device with a Supabase user
ID. If an attacker knows another user's UUID, they could call
`OneSignal.login(victimUserId)` from a modified client to receive that user's
push notifications.

**Recommendation:**

- This is a known limitation of client-side push SDKs. For the starter kit,
  document this risk.
- For production apps requiring stronger guarantees, recommend using OneSignal's
  Identity Verification (HMAC-based):
  ```dart
  OneSignal.login(userId);
  OneSignal.User.pushSubscription.optIn();
  // With identity verification:
  OneSignal.setExternalUserId(userId, authHash); // HMAC(userId, oneSignalRestApiKey)
  ```
- The HMAC must be generated server-side (Edge Function) -- never expose the
  OneSignal REST API key on the client.

### [LOW] Notification Content Security

**Issue:** If push notifications contain sensitive data (e.g., note content in a
"new note shared" notification), that content is visible on lock screens by
default.

**Recommendation:**

- Document best practice: never include sensitive data in notification payloads.
- Use data-only notifications that trigger the app to fetch content securely,
  rather than including content in the push payload.

---

## 8. Local SQLite Data Privacy (Sign-Out Clearing)

### [HIGH] Incomplete Local Data Clearing

**Issue:** The plan mandates `PowerSync.disconnectAndClear()` on sign-out, which
clears the PowerSync SQLite database. However, other local caches may persist:

1. `SharedPreferences` / `NSUserDefaults` (Supabase session tokens if not using
   secure storage).
2. Flutter's image cache.
3. Any Riverpod state cached in memory (should be reset but verify).
4. PostHog local event queue (may contain user-identifying analytics).

**Recommendation:** Define a comprehensive sign-out procedure:

```dart
Future<void> signOut() async {
  // 1. Disconnect and clear PowerSync local database
  await powerSync.disconnectAndClear();

  // 2. Log out of RevenueCat (clears cached customer info)
  await Purchases.logOut();

  // 3. Log out of OneSignal (disassociates device)
  OneSignal.logout();

  // 4. Reset PostHog (clears local queue and identity)
  await Posthog().reset();

  // 5. Clear secure storage (auth tokens)
  await secureStorage.deleteAll();

  // 6. Sign out of Supabase (invalidates session server-side)
  await supabase.auth.signOut();

  // 7. Invalidate all Riverpod providers (handled by router redirect + ProviderScope)
}
```

Add integration tests that verify no user data persists after sign-out.

---

## 9. CI/CD Secret Management in GitHub Actions

### [HIGH] Config File Generation from Secrets

**Issue:** The plan shows
`flutter build appbundle --dart-define-from-file=config_prod.json` in CI but
does not specify how `config_prod.json` gets created in the CI environment.

**Recommendation:**

1. Store the entire JSON content as a single GitHub Actions secret
   (`CONFIG_PROD_JSON`).
2. Write it to disk in the workflow, with restricted permissions:
   ```yaml
   - name: Create production config
     run: |
       echo '${{ secrets.CONFIG_PROD_JSON }}' > config/config_prod.json
       chmod 600 config/config_prod.json
   ```
3. Add a cleanup step after the build:
   ```yaml
   - name: Clean up secrets
     if: always()
     run: rm -f config/config_prod.json
   ```

### [MEDIUM] Fastlane Match Security

**Issue:** The plan references Fastlane Match for code signing but does not
specify the storage backend or encryption.

**Recommendation:**

- Use `match(type: "appstore", storage_mode: "git")` with a PRIVATE repository
  for certificates.
- The Match passphrase must be stored as a GitHub Actions secret
  (`MATCH_PASSWORD`).
- Never use `match(readonly: false)` in CI -- only generate certificates
  locally, and use `readonly: true` in CI.

### [INFO] Workflow Permissions

**Recommendation:**

- Set minimal permissions in workflow files:
  ```yaml
  permissions:
    contents: read
    checks: write # only if needed for test reporting
  ```
- Never use `permissions: write-all` in workflows.

---

## Risk Matrix Summary

| #   | Finding                                      | Severity | OWASP Category                                      |
| --- | -------------------------------------------- | -------- | --------------------------------------------------- |
| 1   | Config files with secrets in source control  | CRITICAL | A05:2021 Security Misconfiguration                  |
| 2   | Incomplete webhook signature validation spec | CRITICAL | A07:2021 Identification and Authentication Failures |
| 3   | Missing `app_user_id` rejection behavior     | CRITICAL | A04:2021 Insecure Design                            |
| 4   | Missing per-operation RLS policies           | HIGH     | A01:2021 Broken Access Control                      |
| 5   | Missing `user_id` DEFAULT + WITH CHECK       | HIGH     | A01:2021 Broken Access Control                      |
| 6   | Webhook replay protection absent             | HIGH     | A08:2021 Software and Data Integrity Failures       |
| 7   | Incomplete local data clearing on sign-out   | HIGH     | A04:2021 Insecure Design                            |
| 8   | CI/CD config file generation unspecified     | HIGH     | A05:2021 Security Misconfiguration                  |
| 9   | Missing CORS configuration on Edge Functions | HIGH     | A05:2021 Security Misconfiguration                  |
| 10  | JWT token stored in unencrypted storage      | MEDIUM   | A02:2021 Cryptographic Failures                     |
| 11  | Auth state listener race condition           | MEDIUM   | A04:2021 Insecure Design                            |
| 12  | Subscriptions table write access unclear     | MEDIUM   | A01:2021 Broken Access Control                      |
| 13  | Edge Function error leakage                  | MEDIUM   | A09:2021 Security Logging and Monitoring Failures   |
| 14  | Fastlane Match security unspecified          | MEDIUM   | A05:2021 Security Misconfiguration                  |
| 15  | Token refresh failure not handled            | MEDIUM   | A07:2021 Identification and Authentication Failures |
| 16  | OTP brute-force client-only protection       | HIGH     | A07:2021 Identification and Authentication Failures |
| 17  | OneSignal identity spoofing                  | LOW      | A07:2021 Identification and Authentication Failures |
| 18  | OTP single-factor limitation                 | LOW      | A07:2021 Identification and Authentication Failures |
| 19  | Notification content on lock screen          | LOW      | A04:2021 Insecure Design                            |
| 20  | Missing `updated_at` trigger                 | INFO     | N/A                                                 |
| 21  | Workflow permissions not minimized           | INFO     | A05:2021 Security Misconfiguration                  |

---

## Remediation Roadmap (Priority Order)

### Immediate (Before Phase 1 Completion)

1. Fix `.gitignore` to exclude ALL config JSON files; create
   `config_example.json` with placeholders.
2. Add `flutter_secure_storage` to dependencies for auth token persistence.

### Before Phase 3 (Data Layer)

3. Write explicit per-operation RLS policies with `WITH CHECK` clauses.
4. Add `DEFAULT auth.uid()` to `user_id` columns.
5. Add `updated_at` trigger.
6. Clarify subscriptions table service-role-only write access.

### Before Phase 4 (Auth)

7. Configure Supabase server-side OTP rate limits (document in README).
8. Wire RevenueCat/OneSignal login to `authStateChanges` stream, not just OTP
   callback.
9. Implement comprehensive sign-out clearing (all 7 steps above).
10. Handle refresh token expiry in `fetchCredentials()`.

### Before Phase 6 (Subscriptions & Push)

11. Fully specify RevenueCat webhook signature validation with timing-safe
    comparison.
12. Implement webhook idempotency via event ID deduplication.
13. Add `app_user_id` validation with proper 400 rejection.
14. Add CORS restrictions on Edge Functions.
15. Wrap Edge Functions in try/catch with sanitized error responses.
16. Document OneSignal identity verification for production hardening.

### Before Phase 7 (CI/CD)

17. Specify CI config file generation from GitHub Secrets with cleanup.
18. Configure Fastlane Match with private repo, readonly in CI.
19. Set minimal `permissions` in all GitHub Actions workflows.
20. Add pre-commit hook rejecting config file commits.

---

_This review covers the plan as specified. Implementation-time code review
should be performed on each phase to verify these recommendations are correctly
applied._
