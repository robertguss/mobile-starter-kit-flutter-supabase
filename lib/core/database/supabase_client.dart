import 'package:flutter_supabase_starter/core/database/secure_auth_storage.dart';
import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabaseClient {
  AppSupabaseClient._();

  static const persistSessionKey = 'sb.persist.session';

  static Future<SupabaseClient> initialize(
    AppEnv env, {
    LocalStorage? localStorage,
  }) async {
    await Supabase.initialize(
      url: env.supabaseUrl,
      anonKey: env.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage:
            localStorage ??
            SecureAuthStorage(persistSessionKey: persistSessionKey),
      ),
    );

    return Supabase.instance.client;
  }
}
