# Package Documentation Research (March 2026)

## Latest Versions (as of 2026-03-10)

| Package             | Version | Min iOS | Notes                                |
| ------------------- | ------- | ------- | ------------------------------------ |
| powersync           | latest  | 13.0    | `powersync` (unified package)        |
| supabase_flutter    | 2.12.0  | 13.0    | All platforms supported              |
| flutter_riverpod    | 3.3.0   | -       | Dart SDK ^3.7.0                      |
| riverpod_annotation | 4.0.2   | -       | With riverpod_generator 4.0.3        |
| go_router           | 17.1.0  | -       | Flutter Favorite, all platforms      |
| purchases_flutter   | 9.13.1  | 11.0    | RevenueCat; iOS, Android, macOS, Web |
| onesignal_flutter   | 5.4.3   | 11.0    | iOS and Android only                 |
| sentry_flutter      | 9.14.0  | 12.0    | Flutter Favorite, all platforms      |
| posthog_flutter     | 5.19.0  | 13.0    | iOS, Android, macOS, Web             |

---

## 1. PowerSync (Flutter SDK)

### Installation

```yaml
dependencies:
  powersync: ^latest
```

### Schema Definition

- Types: `text`, `integer`, `real` (SQLite types)
- No `id` column needed (auto-created as text)
- Schema can be auto-generated from PowerSync Dashboard

```dart
import 'package:powersync/powersync.dart';

const schema = Schema([
  Table('todos', [
    Column.text('list_id'),
    Column.text('created_at'),
    Column.text('description'),
    Column.integer('completed'),
  ], indexes: [
    Index('list', [IndexedColumn('list_id')])
  ]),
  Table('lists', [
    Column.text('created_at'),
    Column.text('name'),
    Column.text('owner_id'),
  ]),
]);
```

### Instantiate Database

```dart
final db = PowerSyncDatabase(schema: schema, path: 'app.db');
await db.initialize();
```

### Backend Connector (Supabase)

Must implement two methods:

1. `fetchCredentials` - returns auth token + PowerSync endpoint
2. `uploadData` - uploads local writes to Supabase

```dart
class SupabaseConnector extends PowerSyncBackendConnector {
  @override
  Future<PowerSyncCredentials> fetchCredentials() async {
    final session = Supabase.instance.client.auth.currentSession;
    return PowerSyncCredentials(
      endpoint: 'https://YOUR_INSTANCE.powersync.journeyapps.com',
      token: session?.accessToken ?? '',
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getCrudBatch();
    if (transaction == null) return;
    for (final op in transaction.crud) {
      // Apply to Supabase via .from(op.table).upsert/delete/insert
    }
    await transaction.complete();
  }
}
```

### Connect after auth

```dart
db.connect(connector: SupabaseConnector());
```

### Sync Rules (Server-side YAML)

Two options: Sync Streams (recommended, edition 3) or Sync Rules (legacy).

**Sync Streams (recommended):**

```yaml
config:
  edition: 3
streams:
  user_data:
    auto_subscribe: true
    queries:
      - SELECT * FROM lists WHERE owner_id = auth.user_id()
      - SELECT todos.* FROM todos INNER JOIN lists ON todos.list_id = lists.id
        WHERE lists.owner_id = auth.user_id()
```

**Sync Rules (legacy):**

```yaml
bucket_definitions:
  user_lists:
    parameters:
      select id as list_id from lists where owner_id = request.user_id()
    data:
      - select * from lists where id = bucket.list_id
      - select * from todos where list_id = bucket.list_id
```

---

## 2. supabase_flutter

### Initialization (must be first, before other SDKs that depend on auth)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(MyApp());
}

final supabase = Supabase.instance.client;
```

### Email OTP Auth

```dart
// Send OTP
await supabase.auth.signInWithOtp(
  email: 'user@example.com',
  emailRedirectTo: kIsWeb ? null : 'io.supabase.flutter://signin-callback/',
);

// Verify OTP (6-digit code)
await supabase.auth.verifyOTP(
  email: 'user@example.com',
  token: '123456',
  type: OtpType.email,
);
```

### signInWithOtp Parameters

- `email` (optional) - email address
- `phone` (optional) - phone number
- `emailRedirectTo` (optional) - redirect URL for magic link
- `shouldCreateUser` (optional, default true)
- `data` (optional) - user metadata
- `captchaToken` (optional)
- `channel` (optional) - `OtpChannel.sms` or `OtpChannel.whatsapp`

### Auth State Listener

```dart
supabase.auth.onAuthStateChange.listen((data) {
  final AuthChangeEvent event = data.event;
  final Session? session = data.session;
});
```

### Deep Links

- Uses `app_links` internally
- Required for: magic link login, email confirmation, password reset, OAuth
- Configure per-platform following app_links docs

---

## 3. flutter_riverpod + riverpod_generator

### Installation

```yaml
dependencies:
  flutter_riverpod: ^3.3.0
  riverpod_annotation: ^4.0.2
dev_dependencies:
  riverpod_generator: ^4.0.3
  build_runner:
```

### Code Generation

Run: `dart run build_runner watch -d`

### Provider Patterns (Code Gen)

**Simple provider (auto-picks type):**

```dart
@riverpod
String example(Ref ref) => 'foo';
```

**Async provider:**

```dart
@riverpod
Future<User> fetchUser(Ref ref, {required int userId}) async {
  final json = await http.get('api/user/$userId');
  return User.fromJson(json);
}
```

**Notifier (stateful):**

```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    return fetchTodos();
  }

  Future<void> addTodo(Todo todo) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.addTodo(todo);
      return fetchTodos();
    });
  }
}
```

### Key Concepts

- Code gen providers are `autoDispose` by default
- Use `@Riverpod(keepAlive: true)` to disable autoDispose
- `Ref` replaces the old typed ref parameter
- No need to choose provider type manually -- the generator infers it
- Recommendation: only use codegen if project already uses it (e.g., Freezed,
  json_serializable). Macros were cancelled by the Dart team.
- Use `ConsumerWidget` not `StatefulWidget` for widgets reading providers
- Use `AsyncValue` for all data fetching state transitions

---

## 4. go_router

### Version: 17.1.0 (Flutter Favorite)

### Basic Configuration

```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
  ],
  redirect: (context, state) {
    final isLoggedIn = /* check auth */;
    final isLoggingIn = state.matchedLocation == '/login';
    if (!isLoggedIn && !isLoggingIn) return '/login';
    if (isLoggedIn && isLoggingIn) return '/';
    return null;
  },
);
```

### Key Features

- Path/query parameter parsing: `user/:id`
- Sub-routes for nested navigation
- `redirect` for auth guards
- `ShellRoute` for persistent UI (e.g., BottomNavigationBar)
- `StatefulShellRoute` for stateful nested navigation
- `refreshListenable` to trigger redirect re-evaluation on auth changes
- Deep linking support
- Type-safe routes available

### MaterialApp Integration

```dart
MaterialApp.router(routerConfig: router)
```

### PostHog Integration

```dart
final router = GoRouter(
  routes: [...],
  observers: [PosthogObserver()],
);
```

---

## 5. purchases_flutter (RevenueCat)

### Version: 9.13.1

### Requirements

- iOS 11.0+, Swift 5.0+
- Android: `launchMode` must be `standard` or `singleTop`
- For Paywalls: MainActivity must extend `FlutterFragmentActivity`

### Android launchMode (critical)

```xml
<activity
    android:name="com.your.Activity"
    android:launchMode="standard" />
```

### MainActivity for Paywalls

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity: FlutterFragmentActivity()
```

### Initialization

```dart
import 'dart:io' show Platform;
import 'package:purchases_flutter/purchases_flutter.dart';

Future<void> initRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);

  late PurchasesConfiguration configuration;
  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration('<google_api_key>');
  } else if (Platform.isIOS) {
    configuration = PurchasesConfiguration('<apple_api_key>');
  }

  await Purchases.configure(configuration);
}
```

### Fetching Offerings

```dart
final offerings = await Purchases.getOfferings();
if (offerings.current != null) {
  // Display packages
}
```

### User Identity

- Use same `appUserID` across platforms for cross-platform subscriptions
- Call `Purchases.logIn(userId)` after authentication
- Web purchases require separate RevenueCat Web Billing setup

---

## 6. onesignal_flutter

### Version: 5.4.3 (v5.x user-centric APIs)

### Installation

```yaml
dependencies:
  onesignal_flutter: ^5.1.2
```

### Initialization

```dart
import 'package:onesignal_flutter/onesignal_flutter.dart';

// In main() or app initialization:
OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
OneSignal.initialize('YOUR_APP_ID');

// Request push permission (iOS)
OneSignal.Notifications.requestPermission(true);
```

### User Identification

```dart
OneSignal.login('external_user_id');
```

### iOS Setup (Required Steps)

1. Add **Push Notifications** capability to app target
2. Add **Background Modes** capability (Remote notifications)
3. Add app target to **App Group** (`group.YOUR_BUNDLE_ID.onesignal`)
4. Add **Notification Service Extension** (NSE) target
5. Add NSE target to same App Group
6. Update NSE code with OneSignal handler
7. Add OneSignal pod to NSE target

### Android Setup

- Configure Firebase credentials in OneSignal dashboard
- Add `google-services.json` to `android/app/`

### Platform Credentials

- iOS: p8 token (recommended) or p12 certificate
- Android: Firebase Cloud Messaging credentials

---

## 7. sentry_flutter

### Version: 9.14.0 (Flutter Favorite)

### Initialization (wraps runApp)

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_DSN';
      options.sendDefaultPii = true;
      // Performance
      options.tracesSampleRate = 1.0;
      // Profiling
      options.profilesSampleRate = 1.0;
      // Session Replay
      options.replay.onErrorSampleRate = 1.0;
      options.replay.sessionSampleRate = 0.1;
      // Logs
      options.enableLogs = true;
    },
    appRunner: () => runApp(
      SentryWidget(child: MyApp()),
    ),
  );
}
```

### Error Capture

```dart
try {
  // code
} catch (exception, stackTrace) {
  await Sentry.captureException(exception, stackTrace: stackTrace);
}
```

### Key Features

- Automatic error handler via `PlatformDispatcher.onError` (Flutter 3.3+)
- Session replay, profiling, logs, metrics (beta)
- `SentryWidget` wrapper for additional context
- go_router integration via `SentryNavigatorObserver`

---

## 8. posthog_flutter

### Version: 5.19.0

### Installation

```yaml
dependencies:
  posthog_flutter: ^5.0.0
```

### Manual Initialization (recommended for session replay + surveys)

**Android** (`AndroidManifest.xml`):

```xml
<meta-data android:name="com.posthog.posthog.AUTO_INIT" android:value="false" />
```

**iOS** (`Info.plist`):

```xml
<key>com.posthog.posthog.AUTO_INIT</key>
<false/>
```

**Dart initialization:**

```dart
final config = PostHogConfig('<ph_project_token>');
config.host = 'https://us.i.posthog.com'; // or eu.i.posthog.com
config.debug = true; // dev only

await Posthog().setup(config);
```

### Minimum Platform Versions

- iOS: 13.0 (set in Podfile)
- Android: API 21 / `compileSdkVersion 34`

### Event Capture

```dart
await Posthog().capture(eventName: 'button_clicked', properties: {'key': 'value'});
```

### Feature Flags

```dart
// Boolean
if (await Posthog().isFeatureEnabled('flag-key')) { ... }

// Multivariate
final variant = await Posthog().getFeatureFlag('flag-key');

// Payload
final payload = await Posthog().getFeatureFlagPayload('flag-key');
```

### User Identification

```dart
await Posthog().identify(userId: 'user_id', userProperties: {'email': 'user@example.com'});
```

### go_router Integration

```dart
final router = GoRouter(
  routes: [...],
  observers: [PosthogObserver()],
);
```

### Session Replay + Surveys

Require manual initialization (AUTO_INIT = false).

---

## Initialization Order Requirements

The recommended initialization order in `main.dart`:

```dart
Future<void> main() async {
  // 1. SENTRY (wraps everything for error capture)
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_DSN';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      // 2. SUPABASE (auth dependency for PowerSync, RevenueCat, OneSignal)
      await Supabase.initialize(url: '...', anonKey: '...');

      // 3. POWERSYNC (depends on Supabase auth for connector)
      final db = PowerSyncDatabase(schema: schema, path: 'app.db');
      await db.initialize();

      // 4. POSTHOG (analytics, no hard dependencies)
      final config = PostHogConfig('token');
      config.host = 'https://us.i.posthog.com';
      await Posthog().setup(config);

      // 5. ONESIGNAL (push notifications)
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize('APP_ID');

      // 6. REVENUECAT (in-app purchases)
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration('api_key'));

      // 7. RUN APP with ProviderScope (Riverpod)
      runApp(
        ProviderScope(
          child: SentryWidget(child: MyApp()),
        ),
      );
    },
  );
}
```

### Why This Order?

1. **Sentry first**: wraps `appRunner` to capture all init errors
2. **Supabase second**: auth tokens needed by PowerSync connector
3. **PowerSync third**: needs Supabase session for `fetchCredentials`
4. **PostHog/OneSignal/RevenueCat**: independent, can be parallel, but after
   auth is available for user identification
5. **ProviderScope**: wraps the widget tree for Riverpod

---

## Compatibility Notes

1. **Dart SDK**: Riverpod 3.3.0 requires Dart ^3.7.0. Ensure your Flutter SDK is
   recent enough.
2. **iOS Minimum**: The highest min iOS across all packages is 13.0 (PostHog,
   PowerSync). Set `platform :ios, '13.0'` in Podfile.
3. **Android compileSdk**: PostHog requires `compileSdkVersion 34`. Others are
   lower.
4. **Riverpod codegen**: Requires `build_runner`. May conflict with
   `json_serializable` -- ensure compatible versions. Consider pinning to
   `riverpod_generator: ^4.0.3`.
5. **RevenueCat + Android**: Must use `FlutterFragmentActivity` for paywalls and
   `launchMode: standard` or `singleTop`.
6. **OneSignal iOS**: Requires Notification Service Extension (separate target)
   for rich notifications and accurate delivery tracking.
7. **PostHog session replay/surveys**: Require manual init (AUTO_INIT=false) on
   both Android and iOS.
8. **supabase_flutter deep links**: Uses `app_links` internally. Needed for
   magic link and OAuth flows.
9. **PowerSync Sync Streams vs Sync Rules**: Sync Streams (edition 3) are the
   recommended approach. Sync Rules are legacy.

---

## Source References

- PowerSync Flutter SDK:
  https://docs.powersync.com/client-sdks/reference/flutter
- PowerSync + Supabase: https://docs.powersync.com/integrations/supabase/guide
- supabase_flutter: https://pub.dev/packages/supabase_flutter
- Supabase Dart Auth OTP:
  https://supabase.com/docs/reference/dart/auth-signinwithotp
- Riverpod Code Gen: https://riverpod.dev/docs/concepts/about_code_generation
- Riverpod Getting Started:
  https://riverpod.dev/docs/introduction/getting_started
- go_router: https://pub.dev/packages/go_router
- RevenueCat Flutter: https://docs.revenuecat.com/docs/flutter
- RevenueCat Getting Started: https://docs.revenuecat.com/docs/getting-started
- OneSignal Flutter Setup:
  https://documentation.onesignal.com/docs/flutter-sdk-setup
- Sentry Flutter: https://docs.sentry.io/platforms/flutter/
- PostHog Flutter: https://posthog.com/docs/libraries/flutter
