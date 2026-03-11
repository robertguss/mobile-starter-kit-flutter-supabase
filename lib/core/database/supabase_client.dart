import 'package:flutter_supabase_starter/core/database/secure_auth_storage.dart';
import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SupabaseInitializer =
    Future<void> Function({
      required String url,
      required String anonKey,
      required FlutterAuthClientOptions authOptions,
    });
typedef SupabaseClientReader = SupabaseClient Function();

class AppSupabaseClient {
  AppSupabaseClient._();

  static const persistSessionKey = 'sb.persist.session';

  static Future<SupabaseClient> initialize(
    AppEnv env, {
    LocalStorage? localStorage,
    SupabaseInitializer? initializeSupabase,
    SupabaseClientReader? readClient,
  }) async {
    await (initializeSupabase ?? _initializeSupabase)(
      url: env.supabaseUrl,
      anonKey: env.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage:
            localStorage ??
            SecureAuthStorage(persistSessionKey: persistSessionKey),
      ),
    );

    return (readClient ?? _readClient)();
  }

  static Future<void> _initializeSupabase({
    required String url,
    required String anonKey,
    required FlutterAuthClientOptions authOptions,
  }) {
    return Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: authOptions,
    );
  }

  static SupabaseClient _readClient() => Supabase.instance.client;
}
