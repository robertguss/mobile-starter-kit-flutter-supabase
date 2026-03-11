# CI/CD & Deployment Review: Flutter Supabase Starter Kit

**Reviewer:** Deployment Verification Agent **Date:** 2026-03-10 **Scope:**
Phase 7 CI/CD plan + cross-cutting deployment concerns from all phases
**Status:** Plan review (greenfield -- no implementation yet)

---

## Executive Summary

The Phase 7 CI/CD plan covers the core happy path (test on PR, build + deploy on
push/tag) but has significant gaps in secret management, build caching, Supabase
Edge Function deployment, environment config security, and rollback procedures.
Below is a Go/No-Go checklist with specific findings and recommendations.

---

## CRITICAL FINDINGS

### 1. config_prod.json Contains Secrets and Is Committed by Design

**Problem:** The plan creates `config_prod.json` with production API keys
(Supabase URL, anon key, Sentry DSN, PostHog key, RevenueCat key, OneSignal ID)
and uses `--dart-define-from-file=config_prod.json` in CI. The `.gitignore` only
mentions adding `config_prod.json`, but the CI workflow needs it during build.

**Risk:** If `config_prod.json` is gitignored (correct), the CI workflow has no
way to access it unless secrets are injected at build time. If it is NOT
gitignored, production keys are in the repository.

**Recommendation:**

- Gitignore ALL config files: `config_dev.json`, `config_staging.json`,
  `config_prod.json`
- In CI, generate `config_prod.json` dynamically from GitHub Secrets:

```yaml
- name: Create prod config
  run: |
    cat > config/config_prod.json << EOF
    {
      "SUPABASE_URL": "${{ secrets.SUPABASE_URL }}",
      "SUPABASE_ANON_KEY": "${{ secrets.SUPABASE_ANON_KEY }}",
      "POWERSYNC_URL": "${{ secrets.POWERSYNC_URL }}",
      "SENTRY_DSN": "${{ secrets.SENTRY_DSN }}",
      "POSTHOG_API_KEY": "${{ secrets.POSTHOG_API_KEY }}",
      "REVENUECAT_API_KEY": "${{ secrets.REVENUECAT_API_KEY }}",
      "ONESIGNAL_APP_ID": "${{ secrets.ONESIGNAL_APP_ID }}"
    }
    EOF
```

- Ship `config_dev.json.example` and `config_prod.json.example` with placeholder
  values as documentation for template users.

### 2. No Supabase Edge Function Deployment in CI

**Problem:** The plan defines two Edge Functions (`revenuecat-webhook` and
`onesignal-trigger`) but no CI workflow deploys them. They exist only in Phase 6
tasks.

**Recommendation:** Add a deployment step or dedicated workflow:

```yaml
# Option A: Add to build workflows after app deploy
- name: Deploy Edge Functions
  run: |
    npx supabase functions deploy revenuecat-webhook --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
    npx supabase functions deploy onesignal-trigger --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
  env:
    SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
# Option B: Dedicated workflow triggered on changes to supabase/functions/
```

### 3. No Supabase Migration Deployment in CI

**Problem:** Database migrations exist in `supabase/migrations/` but no CI
workflow runs them against staging or production. Migrations are only mentioned
in the context of local development (`supabase start`, `supabase db reset`).

**Recommendation:** Add migration deployment:

```yaml
- name: Run migrations
  run: npx supabase db push --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
  env:
    SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

Consider a dedicated `deploy-supabase.yml` workflow that runs migrations and
deploys Edge Functions together, triggered on changes to `supabase/`.

### 4. No Rollback Procedures Defined

**Problem:** The plan has zero mention of rollback for any deployment target:

- No rollback for app store releases
- No rollback for Supabase migrations
- No rollback for Edge Functions
- No rollback for PowerSync sync rules

**Recommendation:** Document rollback procedures per target:

| Target               | Rollback Method                                                                 | Time to Recover             |
| -------------------- | ------------------------------------------------------------------------------- | --------------------------- |
| App (iOS)            | TestFlight allows previous build selection; App Store requires new submission   | Minutes (TF) / Days (Store) |
| App (Android)        | Play Console staged rollback or halt rollout                                    | Minutes                     |
| Supabase Migrations  | Write reverse migration; test locally first with `supabase db reset`            | Minutes-Hours               |
| Edge Functions       | Redeploy previous version: `supabase functions deploy <name>` from prior commit | Minutes                     |
| PowerSync Sync Rules | Revert sync rules in PowerSync dashboard or redeploy prior config               | Minutes                     |

---

## WORKFLOW-SPECIFIC FINDINGS

### test.yml (PR Trigger)

**What the plan says:**

- Trigger on PR to main
- Steps: checkout, Flutter setup, `flutter analyze`, `flutter test --coverage`
- Coverage threshold gate at 80%

**Gaps and Recommendations:**

- [ ] **Missing: Flutter version pinning.** Use `subosito/flutter-action` with
      an explicit version or channel pin. Template users forking this will get
      inconsistent results without it.

  ```yaml
  - uses: subosito/flutter-action@v2
    with:
      flutter-version: "3.x.x" # or channel: 'stable'
      cache: true
  ```

- [ ] **Missing: Dependency caching.** Flutter pub cache and build_runner
      artifacts should be cached. Without caching, every PR run downloads all
      packages and reruns codegen from scratch.

  ```yaml
  - uses: actions/cache@v4
    with:
      path: |
        ~/.pub-cache
        .dart_tool/
      key: flutter-${{ hashFiles('pubspec.lock') }}
  ```

- [ ] **Missing: Codegen step.** The project uses `build_runner` for Riverpod,
      `flutter_gen`, and `slang`. The test workflow must run codegen before
      analyze/test or generated files must be committed. Recommendation: run
      codegen in CI rather than committing generated files.

  ```yaml
  - name: Run code generation
    run: dart run build_runner build --delete-conflicting-outputs
  ```

- [ ] **Missing: Coverage enforcement mechanism.** The plan says 80% threshold
      but does not specify a tool. Options: `very_good_cli`
      (`very_good test --min-coverage 80`), or `lcov` with a check step.

- [ ] **Missing: Format check.** Add `dart format --set-exit-if-changed .` to
      catch formatting issues before merge.

### build-android.yml

**What the plan says:**

- Trigger on push to main or tag
- Steps: checkout, Flutter setup, build appbundle with
  `--dart-define-from-file=config_prod.json`
- Upload to Google Play via Fastlane

**Gaps and Recommendations:**

- [ ] **Missing: Java/JDK setup.** Android builds require JDK. Add:

  ```yaml
  - uses: actions/setup-java@v4
    with:
      distribution: "temurin"
      java-version: "17"
  ```

- [ ] **Missing: Keystore management.** Android release builds require a signing
      keystore. The plan mentions Fastlane but not how the keystore and its
      password are handled. Recommendation:
  - Store keystore as base64-encoded GitHub Secret (`ANDROID_KEYSTORE_BASE64`)
  - Store passwords as secrets (`ANDROID_KEYSTORE_PASSWORD`,
    `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`)
  - Decode in CI:
    ```yaml
    - name: Decode keystore
      run:
        echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 --decode >
        android/app/keystore.jks
    ```

- [ ] **Missing: Google Play Service Account key.** Fastlane needs a service
      account JSON to upload to Play Console. Store as
      `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret.

- [ ] **Missing: Build number management.** App bundles need incrementing
      version codes. Use `--build-number=${{ github.run_number }}` or a
      dedicated versioning strategy.

- [ ] **Missing: Artifact retention.** Upload the `.aab` as a GitHub Actions
      artifact for debugging failed uploads:
  ```yaml
  - uses: actions/upload-artifact@v4
    with:
      name: android-release
      path: build/app/outputs/bundle/release/app-release.aab
  ```

### build-ios.yml

**What the plan says:**

- Trigger on push to main or tag
- Steps: checkout, Flutter setup, code signing via Fastlane Match
- Build IPA with `--dart-define-from-file=config_prod.json`
- Upload to TestFlight via Fastlane

**Gaps and Recommendations:**

- [ ] **Missing: macOS runner specification.** iOS builds require
      `runs-on: macos-latest` (or a pinned macOS version). This is not mentioned
      explicitly.

- [ ] **Missing: Xcode version pinning.** Different Xcode versions produce
      different build results. Pin it:

  ```yaml
  - uses: maxim-lobanov/setup-xcode@v1
    with:
      xcode-version: "15.4"
  ```

- [ ] **Missing: Fastlane Match secrets.** Match needs:
  - `MATCH_PASSWORD` -- encryption password for certificates repo
  - `MATCH_GIT_URL` or `MATCH_STORAGE_MODE` -- where certs are stored
  - `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` or App Store Connect API key
  - Recommendation: Use App Store Connect API key (JSON) stored as a secret,
    which avoids 2FA issues in CI:
    ```yaml
    - name: Setup App Store Connect API Key
      run: |
        mkdir -p ~/.appstoreconnect/private_keys
        echo "${{ secrets.APP_STORE_CONNECT_API_KEY }}" > ~/.appstoreconnect/private_keys/AuthKey.p8
    ```

- [ ] **Missing: CocoaPods caching.** iOS builds pull CocoaPods dependencies.
      Cache them:

  ```yaml
  - uses: actions/cache@v4
    with:
      path: ios/Pods
      key: pods-${{ hashFiles('ios/Podfile.lock') }}
  ```

- [ ] **Missing: Notification Service Extension build config.** OneSignal
      requires an iOS Notification Service Extension target. This must be
      included in the Xcode project and signed with its own provisioning profile
      via Match. The Matchfile needs entries for both the main app and the
      extension bundle ID.

---

## FASTLANE REVIEW

### Fastfile

**What the plan says:** Lanes for `test`, `build_android`, `build_ios`,
`deploy_android`, `deploy_ios`.

**Recommendations:**

- [ ] The `test` lane duplicates `test.yml` functionality. Clarify: is Fastlane
      `test` for local use only, or does it replace the GitHub Actions test
      step? Recommendation: keep `test.yml` as the CI gate; the Fastlane `test`
      lane is for local convenience only.

- [ ] Add explicit error handling in lanes. Fastlane `error` blocks should post
      to Slack/Discord or create a GitHub issue on failure.

- [ ] Add a `beta` lane that builds and uploads to TestFlight/Play internal
      testing without going to production.

### Appfile

- [ ] Must contain `app_identifier` and `apple_id` / `team_id`. Ship with
      placeholder values and document what to change.

### Matchfile

- [ ] Specify `type("appstore")` for production and `type("development")` for
      debug.
- [ ] Must include the Notification Service Extension bundle ID:
  ```ruby
  app_identifier(["com.example.app", "com.example.app.OneSignalNotificationServiceExtension"])
  ```
- [ ] Document that Match requires a private git repo for certificate storage.
      Template users must create this repo themselves.

---

## ENVIRONMENT CONFIGURATION REVIEW

### --dart-define-from-file

**What the plan says:** Three config files (`config_dev.json`,
`config_staging.json`, `config_prod.json`) loaded via `--dart-define-from-file`.

**Findings:**

- [ ] **No staging workflow.** There is `build-android.yml` and `build-ios.yml`
      using prod config, but no workflow for staging builds. Recommendation: add
      a staging build triggered on push to a `staging` branch or via manual
      `workflow_dispatch`.

- [ ] **Env.fromDartDefines() not validated.** The plan shows
      `Env.fromDartDefines()` loading values but does not mention validation.
      Recommendation: the `Env` class should throw a clear error at startup if
      any required key is missing, rather than failing cryptically later.

- [ ] **config_dev.json points to local Supabase.** Document that
      `config_dev.json` should use `http://localhost:54321` (Supabase local) and
      that this file is safe to commit since it contains no real secrets. Only
      `config_staging.json` and `config_prod.json` should be gitignored.

---

## BUILD CACHING STRATEGY (Missing from Plan)

The plan does not mention caching at all. For a Flutter project with codegen,
caching is critical for CI performance.

**Recommended caching layers:**

| Cache Target                       | Key                                | Estimated Time Saved                                   |
| ---------------------------------- | ---------------------------------- | ------------------------------------------------------ |
| Pub cache (`~/.pub-cache`)         | `pubspec.lock` hash                | 30-60s                                                 |
| Gradle cache (`~/.gradle`)         | `android/build.gradle` hash        | 60-120s                                                |
| CocoaPods (`ios/Pods`)             | `Podfile.lock` hash                | 30-90s                                                 |
| Flutter SDK                        | Flutter version string             | 60-120s (use `subosito/flutter-action` built-in cache) |
| build_runner output (`.dart_tool`) | `pubspec.lock` + `build.yaml` hash | 30-60s                                                 |

**Total potential savings: 3-7 minutes per CI run.**

---

## DEPLOYMENT TARGET CONFIGURATION REVIEW

- [ ] **iOS 13.0 minimum:** Acceptable for current Flutter stable. Verify that
      all dependencies (especially `powersync`, `purchases_flutter`,
      `onesignal_flutter`) support iOS 13.0. If any require iOS 14+, the plan
      must be updated.

- [ ] **Android compileSdkVersion 34:** Correct for current Play Store
      requirements. However, also verify `targetSdkVersion` and `minSdkVersion`.
      Recommendation: `minSdkVersion: 21` (Flutter default),
      `targetSdkVersion: 34`.

- [ ] **FlutterFragmentActivity:** Required by RevenueCat. Must be verified in
      CI -- add a check or rely on `flutter analyze` catching it.

---

## GO/NO-GO CHECKLIST

### PRE-IMPLEMENTATION (Required Before Phase 7 Begins)

- [ ] Decide secret management strategy: generate config JSON from GitHub
      Secrets in CI (recommended) vs. encrypted config files in repo
- [ ] Create a private git repo for Fastlane Match certificate storage
- [ ] Obtain App Store Connect API key (p8 file) for CI uploads
- [ ] Obtain Google Play service account JSON for CI uploads
- [ ] Create Android release keystore and document its storage
- [ ] Define build number strategy (GitHub run number, git tag, or manual)
- [ ] Decide whether codegen output is committed or regenerated in CI

### test.yml IMPLEMENTATION CHECKLIST

- [ ] Pin Flutter version with `subosito/flutter-action` and `cache: true`
- [ ] Add pub cache and `.dart_tool` caching
- [ ] Add codegen step (`dart run build_runner build`)
- [ ] Add `dart format --set-exit-if-changed .`
- [ ] Add `flutter analyze`
- [ ] Add `flutter test --coverage`
- [ ] Add coverage threshold enforcement (80% via `very_good_cli` or `lcov`)
- [ ] Add Supabase types generation check if using generated types

### build-android.yml IMPLEMENTATION CHECKLIST

- [ ] Set up JDK 17 with `actions/setup-java`
- [ ] Pin Flutter version
- [ ] Add dependency caching (pub, Gradle)
- [ ] Generate `config_prod.json` from GitHub Secrets
- [ ] Add codegen step
- [ ] Decode Android keystore from secret
- [ ] Build with
      `flutter build appbundle --dart-define-from-file=config/config_prod.json --build-number=${{ github.run_number }}`
- [ ] Upload `.aab` as GitHub Actions artifact
- [ ] Deploy via Fastlane with service account authentication
- [ ] Add Supabase Edge Function deployment step (or separate workflow)

### build-ios.yml IMPLEMENTATION CHECKLIST

- [ ] Use `runs-on: macos-latest` (or pinned version)
- [ ] Pin Xcode version
- [ ] Pin Flutter version
- [ ] Add dependency caching (pub, CocoaPods)
- [ ] Generate `config_prod.json` from GitHub Secrets
- [ ] Add codegen step
- [ ] Set up App Store Connect API key from secret
- [ ] Run Fastlane Match for both main app and NSE bundle IDs
- [ ] Build with
      `flutter build ipa --dart-define-from-file=config/config_prod.json --build-number=${{ github.run_number }}`
- [ ] Upload `.ipa` as GitHub Actions artifact
- [ ] Deploy to TestFlight via Fastlane
- [ ] Add Supabase Edge Function deployment step (or separate workflow)

### MISSING WORKFLOWS TO ADD

- [ ] `deploy-supabase.yml` -- deploy migrations and Edge Functions
  - Trigger: push to main when `supabase/` directory changes
  - Steps: run `supabase db push`, deploy each Edge Function
  - Requires: `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` secrets
- [ ] Staging build workflow (or `workflow_dispatch` input on existing workflows
      to select environment)
- [ ] Dependabot or Renovate config for dependency updates

### ROLLBACK PROCEDURES TO DOCUMENT

- [ ] App rollback: how to halt Play Store rollout, how to select previous
      TestFlight build
- [ ] Supabase migration rollback: reverse migration file, `supabase db push`
- [ ] Edge Function rollback: redeploy from previous git commit
- [ ] PowerSync sync rules rollback: revert in dashboard
- [ ] Feature flag strategy for gradual rollout (not currently in plan but
      strongly recommended)

### POST-DEPLOY MONITORING TO ADD

- [ ] Sentry release tracking: tag releases with version/build number
  ```yaml
  - name: Create Sentry release
    uses: getsentry/action-release@v1
    with:
      environment: production
      version: ${{ github.ref_name }}
  ```
- [ ] Define alert thresholds in Sentry for crash-free rate drop
- [ ] PostHog feature flag integration for gradual rollout
- [ ] App store crash rate monitoring (Play Console, App Store Connect)

---

## SECRETS INVENTORY

Complete list of GitHub Secrets required for CI/CD:

| Secret Name                        | Used By                     | Source                            |
| ---------------------------------- | --------------------------- | --------------------------------- |
| `SUPABASE_URL`                     | config_prod.json generation | Supabase dashboard                |
| `SUPABASE_ANON_KEY`                | config_prod.json generation | Supabase dashboard                |
| `SUPABASE_ACCESS_TOKEN`            | CLI deployment              | Supabase account settings         |
| `SUPABASE_PROJECT_REF`             | CLI deployment              | Supabase dashboard URL            |
| `POWERSYNC_URL`                    | config_prod.json generation | PowerSync dashboard               |
| `SENTRY_DSN`                       | config_prod.json generation | Sentry project settings           |
| `SENTRY_AUTH_TOKEN`                | Release creation            | Sentry account settings           |
| `SENTRY_ORG`                       | Release creation            | Sentry organization slug          |
| `SENTRY_PROJECT`                   | Release creation            | Sentry project slug               |
| `POSTHOG_API_KEY`                  | config_prod.json generation | PostHog project settings          |
| `REVENUECAT_API_KEY`               | config_prod.json generation | RevenueCat dashboard              |
| `ONESIGNAL_APP_ID`                 | config_prod.json generation | OneSignal dashboard               |
| `ANDROID_KEYSTORE_BASE64`          | Android signing             | Generated locally, base64 encoded |
| `ANDROID_KEYSTORE_PASSWORD`        | Android signing             | Set during keystore creation      |
| `ANDROID_KEY_ALIAS`                | Android signing             | Set during keystore creation      |
| `ANDROID_KEY_PASSWORD`             | Android signing             | Set during keystore creation      |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Fastlane Play upload        | Google Cloud Console              |
| `APP_STORE_CONNECT_API_KEY_ID`     | Fastlane TestFlight upload  | App Store Connect                 |
| `APP_STORE_CONNECT_ISSUER_ID`      | Fastlane TestFlight upload  | App Store Connect                 |
| `APP_STORE_CONNECT_API_KEY_P8`     | Fastlane TestFlight upload  | App Store Connect                 |
| `MATCH_PASSWORD`                   | Certificate decryption      | Set during Match init             |
| `MATCH_GIT_URL`                    | Certificate repo            | Private git repo URL              |

**Total: 22 secrets required.** Document setup instructions for each in README.

---

## VERDICT

**NO-GO as currently planned.** The Phase 7 plan covers the skeleton but is
missing critical implementation details that would cause CI failures or security
issues if built as specified. Specifically:

1. **Secret management is undefined** -- the plan cannot work without solving
   how `config_prod.json` is populated in CI
2. **No Supabase deployment pipeline** -- migrations and Edge Functions have no
   CI path to production
3. **No rollback procedures** -- a starter kit shipping to app stores with no
   documented rollback is irresponsible
4. **No build caching** -- CI runs will be painfully slow (10+ minutes) without
   caching
5. **Missing critical CI steps** -- no JDK setup, no Xcode pinning, no codegen,
   no format check

**Path to GO:** Address the items in this checklist before or during Phase 7
implementation. The plan should be updated to explicitly include secret
management, Supabase CI deployment, caching strategy, and rollback procedures.
These are not nice-to-haves -- they are requirements for a "production-ready"
starter kit.
