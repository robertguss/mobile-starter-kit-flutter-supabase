import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/router/app_router.dart';
import 'package:flutter_supabase_starter/features/auth/domain/auth_repository.dart';
import 'package:flutter_supabase_starter/features/auth/domain/user_model.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../domain/mock_auth_repository.dart';

void main() {
  late MockAuthRepository repository;
  late StreamController<UserModel?> authStateController;

  final signedInUser = UserModel(
    id: 'user-123',
    email: 'user@example.com',
    createdAt: DateTime.utc(2026),
  );

  ProviderContainer createContainer({
    AuthRouteStateNotifier? authNotifier,
  }) {
    return ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        authRouteStateProvider.overrideWith(
          (ref) =>
              authNotifier ??
              AuthRouteStateNotifier(AuthRouteState.unauthenticated),
        ),
      ],
    );
  }

  setUp(() {
    repository = MockAuthRepository();
    authStateController = StreamController<UserModel?>.broadcast();

    when(
      repository.authStateChanges,
    ).thenAnswer((_) => authStateController.stream);
  });

  tearDown(() async {
    await authStateController.close();
  });

  test('sendOtp moves through loading and back to idle on success', () async {
    when(() => repository.sendOtp('user@example.com')).thenAnswer((_) async {});

    final container = createContainer();
    addTearDown(container.dispose);
    container.read(authControllerProvider);

    final result = await container
        .read(authControllerProvider.notifier)
        .sendOtp('user@example.com');

    expect(result, isTrue);
    expect(container.read(authControllerProvider).asData?.value, isNull);
    verify(() => repository.sendOtp('user@example.com')).called(1);
  });

  test('sendOtp returns an error state for invalid email', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    container.read(authControllerProvider);

    final result = await container
        .read(authControllerProvider.notifier)
        .sendOtp('invalid-email');

    expect(result, isFalse);
    expect(container.read(authControllerProvider).hasError, isTrue);
    verifyNever(() => repository.sendOtp(any()));
  });

  test('verifyOtp authenticates the user on success', () async {
    when(
      () => repository.verifyOtp('user@example.com', '123456'),
    ).thenAnswer((_) async => signedInUser);

    final authNotifier = AuthRouteStateNotifier(AuthRouteState.unauthenticated);
    final container = createContainer(authNotifier: authNotifier);
    addTearDown(container.dispose);
    addTearDown(authNotifier.dispose);
    final subscription = container.listen(
      authControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    final result = await container
        .read(authControllerProvider.notifier)
        .verifyOtp(email: 'user@example.com', token: '123456');

    expect(result, isTrue);
    expect(
      container.read(authControllerProvider).asData?.value,
      signedInUser,
    );
    expect(authNotifier.state, AuthRouteState.authenticated);
    verify(() => repository.verifyOtp('user@example.com', '123456')).called(1);
  });

  test('verifyOtp surfaces repository errors', () async {
    final exception = Exception('wrong code');
    when(
      () => repository.verifyOtp('user@example.com', '000000'),
    ).thenThrow(exception);

    final container = createContainer();
    addTearDown(container.dispose);
    container.read(authControllerProvider);

    final result = await container
        .read(authControllerProvider.notifier)
        .verifyOtp(email: 'user@example.com', token: '000000');

    expect(result, isFalse);
    expect(container.read(authControllerProvider).error, exception);
    verify(() => repository.verifyOtp('user@example.com', '000000')).called(1);
  });

  test('signOut delegates to the repository and clears auth state', () async {
    when(repository.signOut).thenAnswer((_) async {});

    final authNotifier = AuthRouteStateNotifier(AuthRouteState.authenticated);
    final container = createContainer(authNotifier: authNotifier);
    addTearDown(container.dispose);
    addTearDown(authNotifier.dispose);
    final subscription = container.listen(
      authControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    authStateController.add(signedInUser);
    await Future<void>.delayed(Duration.zero);

    await container.read(authControllerProvider.notifier).signOut();

    expect(container.read(authControllerProvider).asData?.value, isNull);
    expect(authNotifier.state, AuthRouteState.unauthenticated);
    verify(repository.signOut).called(1);
  });

  test('auth state stream updates on sign-in and sign-out', () async {
    final authNotifier = AuthRouteStateNotifier(AuthRouteState.unauthenticated);
    final container = createContainer(authNotifier: authNotifier);
    addTearDown(container.dispose);
    addTearDown(authNotifier.dispose);
    final subscription = container.listen(
      authControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    authStateController.add(signedInUser);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authControllerProvider).asData?.value,
      signedInUser,
    );
    expect(authNotifier.state, AuthRouteState.authenticated);

    authStateController.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authControllerProvider).asData?.value, isNull);
    expect(authNotifier.state, AuthRouteState.unauthenticated);
  });
}
