import 'package:flutter_supabase_starter/core/database/supabase_client.dart';
import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockLocalStorage extends Mock implements LocalStorage {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  test('initialize forwards config and returns the resolved client', () async {
    final localStorage = _MockLocalStorage();
    final client = _MockSupabaseClient();
    String? capturedUrl;
    String? capturedAnonKey;
    FlutterAuthClientOptions? capturedAuthOptions;

    final result = await AppSupabaseClient.initialize(
      const AppEnv(
        supabaseUrl: 'https://supabase.example.com',
        supabaseAnonKey: 'anon-key',
        supabaseRedirectUrl: 'app://callback',
        powerSyncUrl: 'https://powersync.example.com',
        sentryDsn: '',
        posthogApiKey: '',
        posthogHost: '',
        revenueCatApplePublicSdkKey: '',
        revenueCatGooglePublicSdkKey: '',
        oneSignalAppId: '',
      ),
      localStorage: localStorage,
      initializeSupabase: ({
        required url,
        required anonKey,
        required authOptions,
      }) async {
        capturedUrl = url;
        capturedAnonKey = anonKey;
        capturedAuthOptions = authOptions;
      },
      readClient: () => client,
    );

    expect(result, same(client));
    expect(capturedUrl, 'https://supabase.example.com');
    expect(capturedAnonKey, 'anon-key');
    expect(capturedAuthOptions?.localStorage, same(localStorage));
  });
}
