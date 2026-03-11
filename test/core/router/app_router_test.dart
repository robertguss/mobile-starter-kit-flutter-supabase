import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/providers/connectivity_provider.dart';
import 'package:flutter_supabase_starter/core/router/app_router.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/login_screen.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/otp_verify_screen.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_repository.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/note_detail_screen.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_list_screen.dart';
import 'package:flutter_supabase_starter/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_repository.dart';
import 'package:flutter_supabase_starter/features/subscription/presentation/paywall_screen.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/notes/domain/mock_note_repository.dart';
import '../../features/subscription/domain/mock_subscription_repository.dart';

void main() {
  late MockNoteRepository noteRepository;
  late MockSubscriptionRepository subscriptionRepository;

  setUp(() {
    noteRepository = MockNoteRepository();
    subscriptionRepository = MockSubscriptionRepository();
    when(
      () => noteRepository.watchNotes(limit: any(named: 'limit')),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => noteRepository.getNotes(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      subscriptionRepository.watchSubscription,
    ).thenAnswer((_) => const Stream.empty());
    when(
      subscriptionRepository.getSubscription,
    ).thenAnswer(
      (_) async => const SubscriptionModel(
        status: SubscriptionStatus.inactive,
        entitlementId: 'pro',
      ),
    );
    when(
      subscriptionRepository.getAvailablePackages,
    ).thenAnswer((_) async => const []);
  });

  Future<ProviderContainer> pumpRouter(
    WidgetTester tester, {
    required AuthRouteStateNotifier authNotifier,
    required String initialLocation,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authRouteStateProvider.overrideWith((ref) => authNotifier),
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
        noteRepositoryProvider.overrideWithValue(noteRepository),
        subscriptionRepositoryProvider.overrideWithValue(
          subscriptionRepository,
        ),
        routerInitialLocationProvider.overrideWith((ref) => initialLocation),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: Consumer(
            builder: (context, ref, child) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return container;
  }

  testWidgets(
    'redirects unauthenticated users from notes to login',
    (tester) async {
      final container = await pumpRouter(
        tester,
        authNotifier: AuthRouteStateNotifier(AuthRouteState.unauthenticated),
        initialLocation: NotesListScreen.routePath,
      );
      addTearDown(container.dispose);

      expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
      expect(find.byKey(NotesListScreen.screenKey), findsNothing);
    },
  );

  testWidgets('allows unauthenticated users to access otp verification', (
    tester,
  ) async {
    final container = await pumpRouter(
      tester,
      authNotifier: AuthRouteStateNotifier(AuthRouteState.unauthenticated),
      initialLocation: OtpVerifyScreen.routePath,
    );
    addTearDown(container.dispose);

    expect(find.byKey(OtpVerifyScreen.screenKey), findsOneWidget);
    expect(find.byKey(LoginScreen.screenKey), findsNothing);
  });

  testWidgets('redirects authenticated users from login to notes', (
    tester,
  ) async {
    final container = await pumpRouter(
      tester,
      authNotifier: AuthRouteStateNotifier(AuthRouteState.authenticated),
      initialLocation: LoginScreen.routePath,
    );
    addTearDown(container.dispose);

    expect(find.byKey(NotesListScreen.screenKey), findsOneWidget);
    expect(find.byKey(LoginScreen.screenKey), findsNothing);
  });

  testWidgets('builds all configured routes', (tester) async {
    final routes = <({String path, AuthRouteState state, Key key})>[
      (
        path: LoginScreen.routePath,
        state: AuthRouteState.unauthenticated,
        key: LoginScreen.screenKey,
      ),
      (
        path: OtpVerifyScreen.routePath,
        state: AuthRouteState.unauthenticated,
        key: OtpVerifyScreen.screenKey,
      ),
      (
        path: NotificationSettingsScreen.routePath,
        state: AuthRouteState.authenticated,
        key: NotificationSettingsScreen.screenKey,
      ),
      (
        path: PaywallScreen.routePath,
        state: AuthRouteState.authenticated,
        key: PaywallScreen.screenKey,
      ),
      (
        path: '${NoteDetailScreen.routeBasePath}/note-123',
        state: AuthRouteState.authenticated,
        key: NoteDetailScreen.screenKey,
      ),
    ];

    for (final route in routes) {
      final container = await pumpRouter(
        tester,
        authNotifier: AuthRouteStateNotifier(route.state),
        initialLocation: route.path,
      );

      expect(find.byKey(route.key), findsOneWidget);

      container.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
