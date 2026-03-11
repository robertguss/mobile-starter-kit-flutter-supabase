import 'dart:async';

import 'package:flutter_supabase_starter/core/router/app_router.dart';
import 'package:flutter_supabase_starter/features/auth/domain/auth_repository.dart';
import 'package:flutter_supabase_starter/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller.g.dart';

class InvalidEmailAuthException implements Exception {
  const InvalidEmailAuthException();
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  StreamSubscription<UserModel?>? _subscription;

  AuthRepository get _repository => ref.watch(authRepositoryProvider);

  @override
  FutureOr<UserModel?> build() {
    _subscription ??= _repository.authStateChanges().listen(
      _handleAuthStateChanged,
    );
    ref.onDispose(() => _subscription?.cancel());
    return null;
  }

  Future<bool> sendOtp(String email) async {
    final normalizedEmail = email.trim();
    final previousState = state.asData?.value;

    if (!_isValidEmail(normalizedEmail)) {
      state = const AsyncError(
        InvalidEmailAuthException(),
        StackTrace.empty,
      );
      return false;
    }

    state = const AsyncLoading();

    try {
      await _repository.sendOtp(normalizedEmail);
      state = AsyncData(previousState);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String token,
  }) async {
    state = const AsyncLoading();

    try {
      final user = await _repository.verifyOtp(email.trim(), token.trim());
      _handleAuthStateChanged(user);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();

    try {
      await _repository.signOut();
      _handleAuthStateChanged(null);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void _handleAuthStateChanged(UserModel? user) {
    state = AsyncData(user);
    ref
        .read(authRouteStateProvider)
        .update(
          user == null
              ? AuthRouteState.unauthenticated
              : AuthRouteState.authenticated,
        );
  }

  bool _isValidEmail(String email) {
    const pattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    return RegExp(pattern).hasMatch(email);
  }
}
