import 'dart:async';

import 'package:flutter_supabase_starter/core/session/session_manager.dart';
import 'package:flutter_supabase_starter/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_supabase_starter/features/auth/domain/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockSessionManager extends Mock implements SessionManager {}

void main() {
  late _MockSupabaseClient supabaseClient;
  late _MockGoTrueClient authClient;
  late _MockSessionManager sessionManager;
  late SupabaseAuthRepository repository;
  late StreamController<AuthState> authStateController;

  setUp(() {
    supabaseClient = _MockSupabaseClient();
    authClient = _MockGoTrueClient();
    sessionManager = _MockSessionManager();
    authStateController = StreamController<AuthState>.broadcast();

    when(() => supabaseClient.auth).thenReturn(authClient);
    when(
      () => authClient.onAuthStateChange,
    ).thenAnswer((_) => authStateController.stream);

    repository = SupabaseAuthRepository(
      supabaseClient: supabaseClient,
      sessionManager: sessionManager,
    );
  });

  tearDown(() async {
    await authStateController.close();
  });

  test('authStateChanges maps signed-in users', () async {
    final states = <UserModel?>[];
    final subscription = repository.authStateChanges().listen(states.add);
    addTearDown(subscription.cancel);

    authStateController.add(
      AuthState(
        AuthChangeEvent.signedIn,
        Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: _user(email: 'user@example.com'),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      states.single,
      UserModel(
        id: 'user-123',
        email: 'user@example.com',
        createdAt: DateTime.parse('2026-03-11T12:00:00.000Z'),
      ),
    );
  });

  test('authStateChanges emits null for users without email', () async {
    final states = <UserModel?>[];
    final subscription = repository.authStateChanges().listen(states.add);
    addTearDown(subscription.cancel);

    authStateController.add(
      AuthState(
        AuthChangeEvent.signedIn,
        Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: _user(email: null),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(states.single, isNull);
  });

  test('sendOtp delegates to Supabase auth', () async {
    when(
      () => authClient.signInWithOtp(email: 'user@example.com'),
    ).thenAnswer((_) async => AuthResponse());

    await repository.sendOtp('user@example.com');

    verify(() => authClient.signInWithOtp(email: 'user@example.com')).called(1);
  });

  test('signOut delegates to SessionManager teardown', () async {
    when(sessionManager.teardown).thenAnswer((_) async {});

    await repository.signOut();

    verify(sessionManager.teardown).called(1);
  });

  test('verifyOtp maps the user and triggers session setup', () async {
    when(
      () => authClient.verifyOTP(
        email: 'user@example.com',
        token: '123456',
        type: OtpType.email,
      ),
    ).thenAnswer(
      (_) async => AuthResponse(user: _user(email: 'user@example.com')),
    );
    when(() => sessionManager.setup('user-123')).thenAnswer((_) async {});

    final result = await repository.verifyOtp('user@example.com', '123456');

    expect(
      result,
      UserModel(
        id: 'user-123',
        email: 'user@example.com',
        createdAt: DateTime.parse('2026-03-11T12:00:00.000Z'),
      ),
    );
    verify(() => sessionManager.setup('user-123')).called(1);
  });

  test('verifyOtp throws when Supabase does not return a user', () async {
    when(
      () => authClient.verifyOTP(
        email: 'user@example.com',
        token: '123456',
        type: OtpType.email,
      ),
    ).thenAnswer((_) async => AuthResponse());

    await expectLater(
      repository.verifyOtp('user@example.com', '123456'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Expected a signed-in user after OTP verification.',
        ),
      ),
    );
    verifyNever(() => sessionManager.setup(any()));
  });

  test('verifyOtp throws when the returned user is missing an email', () async {
    when(
      () => authClient.verifyOTP(
        email: 'user@example.com',
        token: '123456',
        type: OtpType.email,
      ),
    ).thenAnswer((_) async => AuthResponse(user: _user(email: null)));

    await expectLater(
      repository.verifyOtp('user@example.com', '123456'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Expected a valid user payload after OTP verification.',
        ),
      ),
    );
    verifyNever(() => sessionManager.setup(any()));
  });
}

User _user({required String? email}) {
  return User(
    id: 'user-123',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: email,
    createdAt: '2026-03-11T12:00:00.000Z',
  );
}
