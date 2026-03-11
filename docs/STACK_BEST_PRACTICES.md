# Flutter + Supabase Starter Kit: Stack Best Practices (2025-2026)

Research compiled March 2026. Covers initialization order, architecture
patterns, common pitfalls, and breaking changes.

---

## 1. Flutter + Supabase — Initialization & Auth

### Initialization Order (Critical)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load env vars FIRST
  await dotenv.load(fileName: '.env');

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 3. Initialize PowerSync (after Supabase, needs connector)
  final db = PowerSyncDatabase(schema: schema, path: await getDatabasePath());
  await db.initialize();

  // 4. Connect PowerSync (requires auth token from Supabase)
  db.connect(connector: SupabaseConnector(db));

  // 5. Initialize RevenueCat (after Supabase auth is available)
  // Only call Purchases.configure() once, early in lifecycle
  await Purchases.configure(
    PurchasesConfiguration('<public_sdk_key>')
      ..appUserID = Supabase.instance.client.auth.currentUser?.id,
  );

  // 6. Run app with ProviderScope
  runApp(const ProviderScope(child: MyApp()));
}
```

### Auth Patterns

- Use `Supabase.instance.client.auth.onAuthStateChange` stream for reactive auth
- Deep link setup MUST be configured before `Supabase.initialize()` for magic
  link flows
- Never ship `service_role` keys in client apps; use only the `anon` key (or new
  `sb_publishable_xxx` key)
- Enforce Row Level Security (RLS) on all tables
- Store keys in `.env`, add to `.gitignore`

### Common Pitfalls

- Forgetting `WidgetsFlutterBinding.ensureInitialized()` before any async init
- Not configuring deep links before Supabase init (magic links silently fail)
- Using `service_role` key client-side (security vulnerability)
- Supabase is transitioning to new key formats (`sb_publishable_xxx`); both old
  and new work during transition

### Package Version (as of early 2026)

- `supabase_flutter: ^2.x` (check pub.dev for latest; 2.x is current stable
  line)

---

## 2. PowerSync with Supabase — Offline-First Architecture

### How It Works

PowerSync reads the Postgres Write Ahead Log (WAL) and streams data to a local
SQLite database on device. Client writes go to a local upload queue, processed
when connectivity is available. Non-invasive: no schema changes or write
permissions required on Supabase side.

### Setup Steps

1. Create a Postgres publication in Supabase SQL Editor:
   ```sql
   CREATE PUBLICATION powersync FOR TABLE your_table1, your_table2;
   ```
2. Configure Sync Rules in PowerSync dashboard (YAML, SQL-like syntax)
3. Define client-side schema matching your sync rules
4. Implement a `PowerSyncBackendConnector` for Supabase auth tokens and CRUD
   uploads

### Schema Definition (Client-Side)

```dart
const schema = Schema([
  Table('todos', [
    Column.text('description'),
    Column.integer('completed'),
    Column.text('user_id'),
    Column.text('list_id'),
  ]),
  Table('lists', [
    Column.text('name'),
    Column.text('user_id'),
  ]),
]);
```

### Sync Rules (Server-Side YAML)

```yaml
bucket_definitions:
  user_data:
    parameters:
      - SELECT request.user_id() AS user_id
    data:
      - SELECT * FROM todos WHERE user_id = bucket.user_id
      - SELECT * FROM lists WHERE user_id = bucket.user_id
```

### Architecture Decisions

- PowerSync uses local SQLite; you can also layer Drift (via
  `drift_sqlite_async`) on top for ORM-style queries
- Reads and writes work offline; upload queue syncs when back online
- Realtime sync uses WebSockets when both devices are online
- Schema definitions are validated for duplicates (breaking change in recent
  versions)

### Common Pitfalls

- Forgetting to create the Postgres publication (`powersync`) in Supabase
- Sync rules not matching RLS policies (data visible in sync but blocked by RLS,
  or vice versa)
- Not handling conflict resolution for offline writes
- `DevConnector`/`DevCredentials` are deprecated; will be removed in next major
  release

### Package Version

- `powersync: ^1.17.0` (Dec 2025 release; Rust-based sync client is now default)
- New in 1.17.0: `getCrudTransactions()` for batching upload transactions

---

## 3. Riverpod — State Management Best Practices

### Riverpod 3.0 (Released Sept 2025) — Key Changes

**New Features:**

- **Mutations**: UI can react to side-effects (form submissions, button clicks)
  with loading/success/error
- **Offline Persistence**: Cache providers locally on device; restore on app
  reopen
- **Automatic Retry**: Failed providers automatically retry until success
  (enabled by default)
- **`Ref.mounted`**: Check if a ref is still active (like
  `BuildContext.mounted`)
- **Pause/Resume**: Temporarily pause listeners via `ref.listen`
- **Generics support** in code-generated providers

**Breaking Changes (Migration Required):**

- `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider` moved to
  `legacy.dart` imports
- `AsyncValue.value` returns `null` during errors (was previously the last known
  value)
- `AsyncValue.valueOrNull` removed — use `.value` instead
- `Notifier` and variants are **recreated** on every provider rebuild
- `StreamProvider` pauses its `StreamSubscription` when not actively listened
- `updateShouldNotify` behavior changed (often underestimated in migration)

**Important**: Riverpod 3.0 is a transition release; 4.0 may follow relatively
soon.

### riverpod_generator Best Practices

```dart
// Use @riverpod annotation for all new providers
@riverpod
Future<List<Todo>> todoList(Ref ref) async {
  final db = ref.watch(powerSyncDatabaseProvider);
  return db.getAll('SELECT * FROM todos');
}

// Use @riverpod with class syntax for stateful providers
@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  Future<List<Todo>> build() async {
    final db = ref.watch(powerSyncDatabaseProvider);
    return db.getAll('SELECT * FROM todos');
  }

  Future<void> addTodo(Todo todo) async {
    state = const AsyncValue.loading();
    state = await AsyncGuard(() async {
      await ref.read(todoRepositoryProvider).add(todo);
      return build();
    });
  }
}
```

### Provider Organization (Feature-First)

```
lib/
  features/
    auth/
      data/
        auth_repository.dart
        auth_repository.g.dart        # generated
      presentation/
        login_screen.dart
        auth_providers.dart
        auth_providers.g.dart         # generated
    todos/
      data/
        todo_repository.dart
      presentation/
        todo_list_screen.dart
        todo_providers.dart
  core/
    providers/
      supabase_provider.dart
      powersync_provider.dart
```

### Key Practices

- Prefer `AsyncNotifier` / code-generated `@riverpod class` for all async state
- Use `ref.watch()` in widgets, `ref.read()` only inside callbacks
- Use `ref.select()` to minimize rebuilds
- Keep providers small and focused (single responsibility)
- Family providers for dynamic input (user ID, route params)
- Never put navigation logic inside providers
- Handle `AsyncValue` exhaustively: `when(data:, loading:, error:)`

### Package Versions

- `flutter_riverpod: ^3.0.0`
- `riverpod_annotation: ^3.0.0`
- `riverpod_generator: ^3.0.0`

---

## 4. GoRouter — Routing & Auth Guards

### Declarative Route Definition

```dart
@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,  // triggers redirect on auth change
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/';
      return null; // no redirect
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/todos', builder: (_, __) => const TodoScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ],
  );
}
```

### Auth Guard Pattern with Riverpod

Two approaches:

1. **Global redirect** (recommended): Single redirect function checks auth
   state, handles all route protection
2. **Per-route Guard widget**: Custom `AuthGuard` widget wrapping individual
   routes (GoRouter does NOT provide this natively)

The `refreshListenable` pattern:

- Create an `AuthNotifier` that implements `Listenable`
- Pass it as `refreshListenable` to GoRouter
- When auth state changes, GoRouter re-evaluates all redirects automatically

### Deep Linking (Mobile)

- Define URL scheme in platform configs (iOS: `Info.plist`, Android:
  `AndroidManifest.xml`)
- GoRouter matches deep link paths to route table automatically
- Use `StatefulShellRoute` for bottom navigation with independent nav stacks
- Test deep links with:
  `adb shell am start -a android.intent.action.VIEW -d "myapp://path"`

### Common Pitfalls

- Not passing `refreshListenable` (redirects only run on navigation, not auth
  changes)
- Redirect infinite loops (always return `null` for "no redirect" case)
- Using imperative `context.go()` inside providers (do it in widgets/callbacks
  only)
- Forgetting to handle loading state in redirect (user briefly sees wrong
  screen)

### Package Version

- `go_router: ^14.x` (check pub.dev for latest)

---

## 5. TDD in Flutter — Testing Patterns

### Repository Pattern for Testability

```dart
// Abstract repository (the contract)
abstract class TodoRepository {
  Future<List<Todo>> getAll();
  Future<void> add(Todo todo);
  Future<void> delete(String id);
}

// Concrete implementation
class PowerSyncTodoRepository implements TodoRepository {
  final PowerSyncDatabase db;
  PowerSyncTodoRepository(this.db);

  @override
  Future<List<Todo>> getAll() async {
    final results = await db.getAll('SELECT * FROM todos');
    return results.map(Todo.fromRow).toList();
  }
  // ...
}
```

### Mocktail Patterns

```dart
import 'package:mocktail/mocktail.dart';

// Create mocks
class MockTodoRepository extends Mock implements TodoRepository {}
class MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}

void main() {
  late MockTodoRepository mockRepo;

  setUp(() {
    mockRepo = MockTodoRepository();
  });

  // Register fallback values for custom types
  setUpAll(() {
    registerFallbackValue(Todo(id: '', description: '', completed: false));
  });

  test('returns list of todos', () async {
    // Arrange
    when(() => mockRepo.getAll()).thenAnswer((_) async => [testTodo]);

    // Act
    final result = await mockRepo.getAll();

    // Assert
    expect(result, [testTodo]);
    verify(() => mockRepo.getAll()).called(1);
  });
}
```

### Widget Testing Best Practices

```dart
testWidgets('shows loading then data', (tester) async {
  final mockRepo = MockTodoRepository();
  when(() => mockRepo.getAll()).thenAnswer((_) async => [testTodo]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todoRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: const MaterialApp(home: TodoListScreen()),
    ),
  );

  // Loading state
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Pump until async completes
  await tester.pumpAndSettle();

  // Data state
  expect(find.text('Test Todo'), findsOneWidget);
});
```

### Key Practices

- **TDD Cycle**: Red (failing test) -> Green (minimal code) -> Refactor (clean
  up)
- Mock only at I/O boundaries (repositories, network, database)
- Keep models pure and test them directly (no mocks needed)
- Widget tests verify UI contracts: text, buttons, enabled/disabled, error
  states
- Use `ProviderScope(overrides: [...])` to inject mocks in widget tests
- `registerFallbackValue()` in `setUpAll` for any custom types used with `any()`
- Use `tester.pumpAndSettle()` for async operations, `tester.pump()` for
  frame-by-frame
- Test each layer independently: models -> repositories -> providers -> widgets

### Package Versions

- `mocktail: ^1.0.4`
- `flutter_test` (built-in SDK)

---

## 6. RevenueCat Flutter SDK — In-App Purchases

### Initialization Pattern

```dart
Future<void> initRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug); // remove in production

  final configuration = PurchasesConfiguration('<public_api_key>');

  // If user is already authenticated with Supabase
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    configuration.appUserID = user.id;
  }

  await Purchases.configure(configuration);
}
```

### Login/Logout Flow

```dart
// On Supabase auth sign-in:
final userId = Supabase.instance.client.auth.currentUser!.id;
await Purchases.logIn(userId);

// On sign-out:
await Purchases.logOut(); // reverts to anonymous ID
```

### Webhook with Supabase Edge Function

```typescript
// supabase/functions/revenuecat-webhook/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // Verify webhook signature (IMPORTANT for security)
  const authHeader = req.headers.get("Authorization");
  if (authHeader !== `Bearer ${Deno.env.get("REVENUECAT_WEBHOOK_SECRET")}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const event = await req.json();
  const appUserId = event.event.app_user_id;

  // Skip anonymous IDs
  if (appUserId.startsWith("$RCAnonymousID")) {
    return new Response("Skipped anonymous user", { status: 200 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Update subscription status in your DB
  const { error } = await supabase.from("user_subscriptions").upsert({
    user_id: appUserId,
    is_active: event.event.type !== "EXPIRATION",
    product_id: event.event.product_id,
    updated_at: new Date().toISOString(),
  });

  if (error) return new Response(JSON.stringify(error), { status: 400 });
  return new Response("OK", { status: 200 });
});
```

### Common Pitfalls

- Calling `Purchases.configure()` more than once (configure only once per app
  launch)
- Webhooks receive `$RCAnonymousID` instead of Supabase user ID if `logIn()`
  wasn't called before purchase
- Not verifying webhook signatures in Edge Functions (security risk)
- Using separate API keys per platform (iOS/Android) -- this is REQUIRED for
  hybrid SDKs
- Not handling the case where user purchases before creating an account

### Package Version

- `purchases_flutter: ^8.x` (check pub.dev for latest)

---

## 7. flutter_gen + slang + build_runner — Code Generation

### pubspec.yaml Configuration

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  slang_flutter: ^3.x

dev_dependencies:
  build_runner: ^2.4.x
  flutter_gen_runner: ^5.12.0
  slang_build_runner: ^3.x
  riverpod_generator: ^3.0.0
  json_serializable: ^6.x
  freezed: ^2.x
```

### flutter_gen Configuration (pubspec.yaml)

```yaml
flutter_gen:
  output: lib/gen/
  line_length: 80
  integrations:
    flutter_svg: true
    lottie: true

flutter:
  assets:
    - assets/images/
    - assets/icons/
    - assets/lottie/
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```

### build.yaml — Controlling Generator Order and Scope

```yaml
global_options:
  # Control execution order
  freezed:
    runs_before:
      - json_serializable
  riverpod_generator:
    runs_before:
      - json_serializable

targets:
  $default:
    builders:
      # Scope slang to i18n directory only
      slang_build_runner:
        generate_for:
          include:
            - lib/i18n/**

      # Scope flutter_gen to assets only
      flutter_gen_runner:
        enabled: true

      # Scope riverpod_generator to feature dirs
      riverpod_generator:
        generate_for:
          include:
            - lib/features/**
            - lib/core/**

      # Scope freezed to model files
      freezed:
        generate_for:
          include:
            - lib/**/models/**
            - lib/**/entities/**
```

### slang Configuration (slang.yaml or build.yaml)

```yaml
# If using build.yaml (recommended when combining generators):
# Configure via build.yaml targets section above
# Place translation files in lib/i18n/
# e.g., lib/i18n/strings_en.i18n.json, lib/i18n/strings_es.i18n.json
```

### Running Generators

```bash
# Full build (all generators)
dart run build_runner build --delete-conflicting-outputs

# Watch mode during development
dart run build_runner watch --delete-conflicting-outputs
```

### Performance Optimization

- Use `generate_for` in `build.yaml` to limit which files each generator scans
- This dramatically reduces build times on large projects
- Always use `--delete-conflicting-outputs` to avoid stale generated files
- Consider running `build_runner` with `--verbose` to diagnose slow generators

### Common Pitfalls

- Not using `build.yaml` to scope generators (full-project scan is slow)
- Generator ordering conflicts (use `runs_before` to control sequence)
- slang configured in `slang.yaml` AND `build.yaml` (pick one; `build.yaml` when
  using multiple generators)
- Forgetting `--delete-conflicting-outputs` after changing generator config
- Generated files not in `.gitignore` (debatable; some teams commit them for CI
  speed)

---

## Cross-Cutting Concerns

### Recommended Initialization Order

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Load environment variables (dotenv or --dart-define)
3. `await Supabase.initialize(...)` (needs env vars)
4. `PowerSyncDatabase(schema, path)` + `await db.initialize()` (independent of
   Supabase)
5. `db.connect(connector)` (needs Supabase auth token)
6. `Purchases.configure(...)` (optionally with Supabase user ID)
7. `runApp(ProviderScope(child: MyApp()))` (Riverpod wraps everything)

### Feature-First Project Structure

```
lib/
  app.dart                          # MaterialApp.router with GoRouter
  main.dart                         # initialization
  core/
    providers/                      # shared providers (supabase, powersync, revenuecat)
    models/                         # shared models
    utils/                          # extensions, helpers
    theme/                          # ThemeData, colors, typography
  features/
    auth/
      data/                         # AuthRepository
      presentation/                 # LoginScreen, providers
    todos/
      data/
      presentation/
    settings/
      data/
      presentation/
    subscriptions/
      data/                         # SubscriptionRepository (RevenueCat)
      presentation/                 # PaywallScreen, providers
  gen/                              # flutter_gen output
  i18n/                             # slang translation files
  powersync/
    schema.dart                     # PowerSync schema definition
    connector.dart                  # SupabaseConnector
supabase/
  functions/
    revenuecat-webhook/index.ts     # Edge Function
  migrations/                       # SQL migrations
test/
  features/
    auth/
      data/
        auth_repository_test.dart
      presentation/
        login_screen_test.dart
    todos/
      ...
```

### Version Compatibility Matrix (Early 2026 — verify on pub.dev)

| Package               | Version | Notes                                     |
| --------------------- | ------- | ----------------------------------------- |
| `supabase_flutter`    | ^2.x    | New key format transition                 |
| `powersync`           | ^1.17.0 | Rust sync client now default              |
| `flutter_riverpod`    | ^3.0.0  | Major breaking changes from 2.x           |
| `riverpod_generator`  | ^3.0.0  | Required with Riverpod 3.0                |
| `riverpod_annotation` | ^3.0.0  | Required with Riverpod 3.0                |
| `go_router`           | ^14.x   | Stable, maintained by Flutter team        |
| `purchases_flutter`   | ^8.x    | Separate keys per platform                |
| `flutter_gen_runner`  | ^5.12.0 | Dev dependency                            |
| `slang_flutter`       | ^3.x    | Runtime; `slang_build_runner` for codegen |
| `mocktail`            | ^1.0.4  | Test dependency                           |
| `build_runner`        | ^2.4.x  | Dev dependency                            |

**IMPORTANT**: Always run `flutter pub upgrade --major-versions` and check
pub.dev for the actual latest before starting. Versions above are directional
based on research.

---

## Sources

- [PowerSync + Supabase Integration Guide](https://docs.powersync.com/integration-guides/supabase-+-powersync)
- [PowerSync Blog: Offline-First for Supabase](https://www.powersync.com/blog/bringing-offline-first-to-supabase)
- [Building Local-First Flutter Apps with Riverpod, Drift, and PowerSync](https://dinkomarinac.dev/blog/building-local-first-flutter-apps-with-riverpod-drift-and-powersync/)
- [Riverpod 3.0 What's New](https://riverpod.dev/docs/whats_new)
- [Riverpod 3.0 Migration Guide](https://riverpod.dev/docs/3.0_migration)
- [CodeWithAndrea: Riverpod 3.0 Newsletter](https://codewithandrea.com/newsletter/september-2025/)
- [CodeWithAndrea: Riverpod Generator](https://codewithandrea.com/articles/flutter-riverpod-generator/)
- [GoRouter + Riverpod Redirect Pattern](https://apparencekit.dev/blog/flutter-riverpod-gorouter-redirect/)
- [Guarding Routes with GoRouter and Riverpod](https://dinkomarinac.dev/blog/guarding-routes-in-flutter-with-gorouter-and-riverpod/)
- [Flutter Official: Navigation and Routing](https://docs.flutter.dev/ui/navigation)
- [Flutter Official: Testing Architecture Case Study](https://docs.flutter.dev/app-architecture/case-study/testing)
- [Supabase Flutter Quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Supabase Dart API Reference](https://supabase.com/docs/reference/dart/initializing)
- [RevenueCat: Configuring the SDK](https://www.revenuecat.com/docs/getting-started/configuring-sdk)
- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [FlutterGen GitHub](https://github.com/FlutterGen/flutter_gen)
- [CodeWithAndrea: Speed Up build_runner](https://codewithandrea.com/tips/speed-up-code-generation-build-runner-dart-flutter/)
- [PowerSync Flutter SDK Changelog](https://pub.dev/packages/powersync/changelog)
