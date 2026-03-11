import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/features/auth/domain/auth_repository.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/login_screen.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/otp_verify_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../domain/mock_auth_repository.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(repository.authStateChanges).thenAnswer((_) => const Stream.empty());
  });

  GoRouter buildRouter() {
    return GoRouter(
      routes: [
        GoRoute(
          path: LoginScreen.routePath,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: OtpVerifyScreen.routePath,
          builder: (context, state) => OtpVerifyScreen(
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ],
      initialLocation: LoginScreen.routePath,
    );
  }

  testWidgets('renders email input and submit button', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });

  testWidgets('shows validation error for invalid email', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    verifyNever(() => repository.sendOtp(any()));
  });

  testWidgets('shows loading state while sending OTP', (tester) async {
    final completer = Completer<void>();
    when(() => repository.sendOtp('user@example.com')).thenAnswer(
      (_) => completer.future,
    );

    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('navigates to the OTP screen on success', (tester) async {
    when(() => repository.sendOtp('user@example.com')).thenAnswer((_) async {});

    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byKey(OtpVerifyScreen.screenKey), findsOneWidget);
  });

  testWidgets('shows error snackbar on failure', (tester) async {
    when(
      () => repository.sendOtp('user@example.com'),
    ).thenThrow(Exception('rate limited'));

    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('We could not send a code right now.'), findsOneWidget);
  });
}
