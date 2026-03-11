---
title: "CI/CD Recommendations for Flutter & Supabase Starter Kit"
type: recommendations
status: draft
date: 2026-03-10
source_plan: docs/plans/2026-03-10-feat-flutter-supabase-starter-kit-plan.md
source_skills:
  cicd-automation/1.2.2 (deployment-pipeline-design, github-actions-templates,
  secrets-management)
---

# CI/CD Recommendations for Flutter & Supabase Starter Kit

Concrete CI/CD recommendations for Phase 7 of the plan, applying CI/CD
automation skill patterns to Flutter-specific workflows.

---

## 1. test.yml -- PR Test Workflow

### Recommended Implementation

```yaml
name: Test

on:
  pull_request:
    branches: [main]

concurrency:
  group: test-${{ github.head_ref }}
  cancel-in-progress: true

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true # Caches Flutter SDK between runs

      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.PUB_CACHE }}
            .dart_tool/
          key: pub-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generators
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze --fatal-infos

      - name: Run tests with coverage
        run: flutter test --coverage --test-randomize-ordering-seed=random

      - name: Check coverage threshold
        run: |
          COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | awk '{print $2}' | sed 's/%//')
          echo "Coverage: ${COVERAGE}%"
          if (( $(echo "$COVERAGE < 80.0" | bc -l) )); then
            echo "::error::Coverage ${COVERAGE}% is below 80% threshold"
            exit 1
          fi

      - name: Upload coverage
        if: always()
        uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
          fail_ci_if_error: false
```

### Key Recommendations

- **Flutter SDK caching**: `subosito/flutter-action@v2` with `cache: true` saves
  ~2 minutes per run by caching the Flutter SDK download.
- **Pub cache**: Separate `actions/cache@v4` for `PUB_CACHE` keyed on
  `pubspec.lock` hash. This is the single highest-impact cache for Flutter CI.
- **Concurrency control**: Cancel in-progress runs for the same PR branch.
  Flutter tests are expensive; don't waste runner minutes on stale commits.
- **build_runner in CI**: Required because generated files (Riverpod
  controllers, slang, flutter_gen) should NOT be committed. Generate fresh in CI
  to catch codegen drift.
- **Coverage gate**: Parse `lcov.info` and fail if below 80%. The plan specifies
  this threshold; enforce it as a hard gate, not just a report.
- **Test randomization**: `--test-randomize-ordering-seed=random` catches
  order-dependent test failures early.

---

## 2. build-android.yml -- Android Build & Deploy

### Recommended Implementation

```yaml
name: Build Android

on:
  push:
    branches: [main]
    tags: ["v*"]

concurrency:
  group: build-android-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-android:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
          cache: gradle

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.PUB_CACHE }}
            .dart_tool/
          key: pub-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generators
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Decode keystore
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/app/keystore.jks
          echo "storeFile=keystore.jks" >> android/key.properties
          echo "storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}" >> android/key.properties
          echo "keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}" >> android/key.properties
          echo "keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}" >> android/key.properties

      - name: Write production config
        run: |
          echo '${{ secrets.CONFIG_PROD_JSON }}' > config/config_prod.json

      - name: Build App Bundle
        run: |
          flutter build appbundle \
            --release \
            --dart-define-from-file=config/config_prod.json \
            --build-number=${{ github.run_number }}

      - name: Upload App Bundle artifact
        uses: actions/upload-artifact@v4
        with:
          name: android-appbundle
          path: build/app/outputs/bundle/release/app-release.aab
          retention-days: 30

  deploy-android:
    needs: build-android
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    environment:
      name: production-android

    steps:
      - uses: actions/checkout@v4

      - name: Download App Bundle
        uses: actions/download-artifact@v4
        with:
          name: android-appbundle
          path: build/

      - name: Setup Ruby for Fastlane
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.2"
          bundler-cache: true
          working-directory: android

      - name: Decode Play Store service account
        run: |
          echo "${{ secrets.PLAY_STORE_SERVICE_ACCOUNT_JSON }}" | base64 -d > android/play-store-key.json

      - name: Deploy to Google Play (Internal Testing)
        run: |
          cd android && bundle exec fastlane deploy_android
        env:
          SUPPLY_JSON_KEY: play-store-key.json

      - name: Clean up secrets
        if: always()
        run: |
          rm -f android/app/keystore.jks android/key.properties android/play-store-key.json config/config_prod.json
```

### Key Recommendations

- **Java 17 + Gradle caching**: `actions/setup-java@v4` with `cache: gradle`
  caches `~/.gradle/caches` and `~/.gradle/wrapper`. This saves 3-5 minutes on
  Android builds. Java 17 is required for AGP 8.x (compileSdkVersion 34).
- **Keystore as base64 secret**: Store the `.jks` file as a base64-encoded
  GitHub secret. Decode at build time, clean up in `always()` step. Never commit
  keystores.
- **Config injection**: Write `config_prod.json` from a secret at build time.
  The plan already has `config_prod.json` in `.gitignore` -- this completes that
  pattern.
- **Build number from run_number**: `--build-number=${{ github.run_number }}`
  gives monotonically increasing build numbers without manual management.
- **Tag-gated deployment**: Build on every push to main (for validation), but
  only deploy to Google Play on version tags (`v*`). This follows the
  deployment-pipeline-design skill's approval gate pattern.
- **Environment protection**: The `production-android` environment should have
  required reviewers configured in GitHub repo settings. This adds a manual
  approval gate before app store deployment.
- **Fastlane for deployment**: Use Fastlane's `supply` action for Google Play
  uploads. Deploy to Internal Testing track first, promote manually.

---

## 3. build-ios.yml -- iOS Build & Deploy

### Recommended Implementation

```yaml
name: Build iOS

on:
  push:
    branches: [main]
    tags: ["v*"]

concurrency:
  group: build-ios-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-ios:
    runs-on: macos-14 # Apple Silicon runner (M1), much faster for iOS builds
    timeout-minutes: 45

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ${{ env.PUB_CACHE }}
            .dart_tool/
          key: pub-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-

      - name: Cache CocoaPods
        uses: actions/cache@v4
        with:
          path: ios/Pods
          key: pods-${{ runner.os }}-${{ hashFiles('ios/Podfile.lock') }}
          restore-keys: |
            pods-${{ runner.os }}-

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generators
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Write production config
        run: |
          echo '${{ secrets.CONFIG_PROD_JSON }}' > config/config_prod.json

      - name: Setup Ruby for Fastlane
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.2"
          bundler-cache: true
          working-directory: ios

      - name: Setup code signing via Match
        run: |
          cd ios && bundle exec fastlane match appstore --readonly
        env:
          MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION:
            ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}

      - name: Build IPA
        run: |
          flutter build ipa \
            --release \
            --dart-define-from-file=config/config_prod.json \
            --build-number=${{ github.run_number }} \
            --export-options-plist=ios/ExportOptions.plist

      - name: Upload IPA artifact
        uses: actions/upload-artifact@v4
        with:
          name: ios-ipa
          path: build/ios/ipa/*.ipa
          retention-days: 30

  deploy-ios:
    needs: build-ios
    runs-on: macos-14
    if: startsWith(github.ref, 'refs/tags/v')
    environment:
      name: production-ios

    steps:
      - uses: actions/checkout@v4

      - name: Download IPA
        uses: actions/download-artifact@v4
        with:
          name: ios-ipa
          path: build/

      - name: Setup Ruby for Fastlane
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.2"
          bundler-cache: true
          working-directory: ios

      - name: Deploy to TestFlight
        run: |
          cd ios && bundle exec fastlane deploy_ios
        env:
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          APP_STORE_CONNECT_API_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_CONTENT: ${{ secrets.ASC_KEY_CONTENT }}

      - name: Clean up secrets
        if: always()
        run: |
          rm -f config/config_prod.json
```

### Key Recommendations

- **macos-14 (Apple Silicon)**: Use M1 runners. They are 2-3x faster than Intel
  macOS runners for Flutter iOS builds and CocoaPods installation. This is the
  single biggest time saver for iOS CI.
- **CocoaPods caching**: Cache `ios/Pods` keyed on `Podfile.lock`. CocoaPods
  install is one of the slowest steps (~3-5 min). Cache cuts this to seconds.
- **Fastlane Match for code signing**: The plan already specifies a `Matchfile`.
  Use `match appstore --readonly` in CI so the runner never modifies signing
  certs, only reads them. Store the Match repo credentials as secrets.
- **App Store Connect API key (not password)**: Use API key authentication for
  TestFlight uploads. It is more reliable than Apple ID + app-specific password
  and doesn't trigger 2FA issues in CI. Store the `.p8` key content as a secret.
- **ExportOptions.plist**: Required for `flutter build ipa`. Create this file
  with the correct provisioning profile name and team ID. Commit it to the repo
  (it contains no secrets).
- **Separate deploy job with environment gate**: Same pattern as Android --
  build on main, deploy only on tags with manual approval.

---

## 4. Fastlane Configuration

### fastlane/Fastfile

```ruby
default_platform(:ios)

# --- Android Lanes ---
platform :android do
  desc "Deploy Android to Google Play Internal Testing"
  lane :deploy_android do
    upload_to_play_store(
      track: "internal",
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      json_key: "play-store-key.json",
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end

  desc "Promote Internal Testing to Production"
  lane :promote_android do
    upload_to_play_store(
      track: "internal",
      track_promote_to: "production",
      json_key: "play-store-key.json",
      skip_upload_changelogs: false
    )
  end
end

# --- iOS Lanes ---
platform :ios do
  desc "Sync code signing certificates"
  lane :sync_certs do
    match(type: "appstore", readonly: true)
  end

  desc "Deploy iOS to TestFlight"
  lane :deploy_ios do
    api_key = app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_API_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_API_KEY_CONTENT"],
      is_key_content_base64: false
    )

    upload_to_testflight(
      api_key: api_key,
      ipa: "../build/ios/ipa/flutter_supabase_starter.ipa",
      skip_waiting_for_build_processing: true
    )
  end

  desc "Promote TestFlight to App Store"
  lane :promote_ios do
    api_key = app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_API_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_API_KEY_CONTENT"],
      is_key_content_base64: false
    )

    deliver(
      api_key: api_key,
      skip_binary_upload: true,
      submit_for_review: true,
      automatic_release: false,
      force: true
    )
  end
end
```

### fastlane/Matchfile

```ruby
git_url(ENV["MATCH_GIT_URL"] || "https://github.com/your-org/certificates.git")
storage_mode("git")
type("appstore")
app_identifier(["com.example.fluttersupabasestarter"])
# For the OneSignal Notification Service Extension:
# app_identifier(["com.example.fluttersupabasestarter", "com.example.fluttersupabasestarter.OneSignalNotificationServiceExtension"])
```

---

## 5. Secrets Management Strategy

Applying the secrets-management skill to the specific needs of this starter kit.

### Required GitHub Secrets (Repository Level)

| Secret                            | Purpose                             | Notes                                                   |
| --------------------------------- | ----------------------------------- | ------------------------------------------------------- |
| `CONFIG_PROD_JSON`                | Full production config JSON         | Contains all API keys (Supabase, Sentry, PostHog, etc.) |
| `ANDROID_KEYSTORE_BASE64`         | Android signing keystore            | `base64 -w 0 keystore.jks`                              |
| `ANDROID_KEYSTORE_PASSWORD`       | Keystore password                   |                                                         |
| `ANDROID_KEY_ALIAS`               | Key alias                           |                                                         |
| `ANDROID_KEY_PASSWORD`            | Key password                        |                                                         |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | Google Play API access              | Base64-encoded service account JSON                     |
| `MATCH_GIT_URL`                   | Fastlane Match certificates repo    | Private git repo URL                                    |
| `MATCH_PASSWORD`                  | Fastlane Match encryption password  |                                                         |
| `MATCH_GIT_BASIC_AUTHORIZATION`   | Git auth for Match repo             | `base64("username:token")`                              |
| `ASC_KEY_ID`                      | App Store Connect API key ID        |                                                         |
| `ASC_ISSUER_ID`                   | App Store Connect issuer ID         |                                                         |
| `ASC_KEY_CONTENT`                 | App Store Connect `.p8` key content | Raw key content, not base64                             |

### Environment-Level Secrets

Configure two GitHub environments with required reviewers:

- **production-android**: Required reviewer before Google Play deployment
- **production-ios**: Required reviewer before TestFlight deployment

### Secret Scanning

Add to `.gitignore` (the plan already includes `config_prod.json`):

```
config/config_prod.json
*.jks
*.keystore
*.p8
*.p12
**/play-store-key.json
**/key.properties
```

### Template User Guidance

Since this is a GitHub template repo, include a `config/config_template.json`
with placeholder values and document the full secrets setup in README.md. Users
clicking "Use this template" need clear instructions for populating their own
secrets.

---

## 6. Caching Strategy Summary

| Cache Target         | Key                                                     | Estimated Savings |
| -------------------- | ------------------------------------------------------- | ----------------- |
| Flutter SDK          | Built into `subosito/flutter-action` with `cache: true` | ~2 min            |
| Pub packages         | `pub-{os}-{hash(pubspec.lock)}`                         | ~1 min            |
| Gradle (Android)     | Built into `setup-java` with `cache: gradle`            | ~3-5 min          |
| CocoaPods (iOS)      | `pods-{os}-{hash(Podfile.lock)}`                        | ~3-5 min          |
| Ruby gems (Fastlane) | Built into `setup-ruby` with `bundler-cache: true`      | ~1 min            |

**Total estimated savings per run: 10-14 minutes** on warm cache hits.

---

## 7. Pipeline Flow Summary

```
PR opened/updated
  --> test.yml: analyze + test + coverage gate (80%)
      [blocks merge if failing]

Push to main (merge)
  --> build-android.yml: build AAB, upload artifact
  --> build-ios.yml: build IPA, upload artifact
      [artifacts retained 30 days for debugging]

Tag v* pushed
  --> build-android.yml: build AAB --> [manual approval] --> deploy to Google Play Internal
  --> build-ios.yml: build IPA --> [manual approval] --> deploy to TestFlight
      [promote to production manually via Fastlane lanes]
```

This follows the deployment-pipeline-design skill's recommended flow: Build -->
Test --> Staging (internal/TestFlight) --> Approval Gate --> Production.

---

## 8. Additional Recommendations

### What the Plan Is Missing

1. **Supabase Edge Function deployment**: Add a workflow to deploy Edge
   Functions on push to main. Use `supabase functions deploy` with
   `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` secrets.

2. **Database migration CI**: Add a step (or separate workflow) that runs
   `supabase db push` for staging/production Supabase projects on merge to main.
   This prevents migration drift.

3. **Dart format check**: Add `dart format --set-exit-if-changed .` to
   `test.yml` before analyze. Catches formatting issues that `flutter analyze`
   does not.

4. **build_runner verify step**: After running `build_runner build` in CI, run
   `git diff --exit-code` to verify no generated files were committed out of
   sync. This catches developers who forget to regenerate.

5. **OneSignal Notification Service Extension signing**: The `Matchfile` needs
   to include the NSE bundle ID alongside the main app. I included a commented
   line in the Matchfile above.

6. **Dependabot or Renovate**: Configure automated dependency updates for
   Flutter packages, GitHub Actions versions, and Ruby gems. Critical for a
   template repo that needs to stay current.

7. **Branch protection rules**: Document that users should enable:
   - Require PR reviews before merge
   - Require status checks (test.yml) to pass
   - Require branches to be up to date before merge

8. **Workflow for Supabase local test**: Consider a workflow that runs
   `supabase start` in CI with Docker to run integration tests against a real
   local Supabase instance. This validates migrations + RLS policies
   automatically.
