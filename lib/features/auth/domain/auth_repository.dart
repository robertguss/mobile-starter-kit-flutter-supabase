import 'package:flutter_supabase_starter/features/auth/domain/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<void> sendOtp(String email);

  Future<UserModel> verifyOtp(String email, String token);

  Future<void> signOut();

  Stream<UserModel?> authStateChanges();
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  throw UnimplementedError(
    'Override authRepositoryProvider with a concrete implementation.',
  );
}
