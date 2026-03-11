import 'package:flutter/foundation.dart';
import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports which SDKs are configured', () {
    const env = AppEnv(
      supabaseUrl: 'https://supabase.example.com',
      supabaseAnonKey: 'anon-key',
      supabaseRedirectUrl: 'app://callback',
      powerSyncUrl: 'https://powersync.example.com',
      sentryDsn: 'https://example@sentry.io/1',
      posthogApiKey: 'phc_123',
      posthogHost: 'https://posthog.example.com',
      revenueCatApplePublicSdkKey: 'apple-key',
      revenueCatGooglePublicSdkKey: 'google-key',
      oneSignalAppId: 'onesignal-app-id',
    );

    expect(env.hasSupabaseConfig, isTrue);
    expect(env.hasSentryConfig, isTrue);
    expect(env.hasPosthogConfig, isTrue);
    expect(env.hasRevenueCatConfig, isTrue);
    expect(env.hasOneSignalConfig, isTrue);
  });

  test('selects the platform-appropriate RevenueCat public key', () {
    const env = AppEnv(
      supabaseUrl: '',
      supabaseAnonKey: '',
      supabaseRedirectUrl: '',
      powerSyncUrl: '',
      sentryDsn: '',
      posthogApiKey: '',
      posthogHost: '',
      revenueCatApplePublicSdkKey: 'apple-key',
      revenueCatGooglePublicSdkKey: 'google-key',
      oneSignalAppId: '',
    );

    final expectedKey = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'google-key',
      TargetPlatform.iOS || TargetPlatform.macOS => 'apple-key',
      _ => '',
    };

    expect(env.revenueCatPublicSdkKey, expectedKey);
  });
}
