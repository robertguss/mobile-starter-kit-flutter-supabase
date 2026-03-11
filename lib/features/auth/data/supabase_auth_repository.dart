import 'package:flutter_supabase_starter/core/session/session_manager.dart';
import 'package:flutter_supabase_starter/features/auth/domain/auth_repository.dart';
import 'package:flutter_supabase_starter/features/auth/domain/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseClient supabaseClient,
    required SessionManager sessionManager,
  })  : _supabaseClient = supabaseClient,
        _sessionManager = sessionManager;

  final SupabaseClient _supabaseClient;
  final SessionManager _sessionManager;

  @override
  Stream<UserModel?> authStateChanges() {
    return _supabaseClient.auth.onAuthStateChange.map(
      (authState) => _mapUser(authState.session?.user),
    );
  }

  @override
  Future<void> sendOtp(String email) {
    return _supabaseClient.auth.signInWithOtp(email: email);
  }

  @override
  Future<void> signOut() {
    return _sessionManager.teardown();
  }

  @override
  Future<UserModel> verifyOtp(String email, String token) async {
    final response = await _supabaseClient.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );

    final user = response.user;
    if (user == null) {
      throw StateError('Expected a signed-in user after OTP verification.');
    }

    final mappedUser = _mapUser(user);
    if (mappedUser == null) {
      throw StateError('Expected a valid user payload after OTP verification.');
    }

    await _sessionManager.setup(mappedUser.id);
    return mappedUser;
  }

  UserModel? _mapUser(User? user) {
    if (user == null || user.email == null) {
      return null;
    }

    return UserModel(
      id: user.id,
      email: user.email!,
      createdAt: DateTime.parse(user.createdAt),
    );
  }
}
