import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/features/auth/domain/auth_repository.dart';
import 'package:flutter_supabase_starter/features/auth/domain/user_model.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/login_screen.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/otp_verify_screen.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../domain/mock_auth_repository.dart';

void main() {
  late MockAuthRepository repository;

  final signedInUser = UserModel(
    id: 'user-123',
    email: 'user@example.com',
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    repository = MockAuthRepository();
    when(repository.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(() => repository.sendOtp(any())).thenAnswer((_) async {});
    when(repository.signOut).thenAnswer((_) async {});
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
            email: state.uri.queryParameters['email'] ?? 'user@example.com',
          ),
        ),
        GoRoute(
          path: NotesListScreen.routePath,
          builder: (context, state) => const NotesListScreen(),
        ),
      ],
      initialLocation: OtpVerifyScreen.routeLocation('user@example.com'),
    );
  }

  testWidgets('renders OTP input field', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verify code'), findsOneWidget);
  });

  testWidgets('shows loading during verification', (tester) async {
    final completer = Completer<UserModel>();
    when(
      () => repository.verifyOtp('user@example.com', '123456'),
    ).thenAnswer((_) => completer.future);

    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(signedInUser);
    await tester.pumpAndSettle();
  });

  testWidgets('navigates to home on success', (tester) async {
    when(
      () => repository.verifyOtp('user@example.com', '123456'),
    ).thenAnswer((_) async => signedInUser);

    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(find.byKey(NotesListScreen.screenKey), findsOneWidget);
  });

  testWidgets('shows error for wrong code', (tester) async {
    when(
      () => repository.verifyOtp('user@example.com', '000000'),
    ).thenThrow(Exception('wrong code'));

    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('That code is invalid or expired.'), findsOneWidget);
  });

  testWidgets('resend OTP button starts a cooldown timer', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.tap(find.text('Resend code'));
    await tester.pump();

    expect(find.text('Resend in 30s'), findsOneWidget);
    verify(() => repository.sendOtp('user@example.com')).called(1);
  });
}
