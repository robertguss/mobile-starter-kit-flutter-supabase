import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:flutter_supabase_starter/core/observability/posthog_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

void main() {
  test('skips setup when PostHog is not configured', () async {
    var didSetup = false;

    await PosthogConfig.initialize(
      const AppEnv(
        supabaseUrl: '',
        supabaseAnonKey: '',
        supabaseRedirectUrl: '',
        powerSyncUrl: '',
        sentryDsn: '',
        posthogApiKey: '',
        posthogHost: '',
        revenueCatApplePublicSdkKey: '',
        revenueCatGooglePublicSdkKey: '',
        oneSignalAppId: '',
      ),
      setupPosthog: (_) async {
        didSetup = true;
      },
    );

    expect(didSetup, isFalse);
  });

  test('builds the expected PostHog config when enabled', () async {
    PostHogConfig? capturedConfig;

    await PosthogConfig.initialize(
      const AppEnv(
        supabaseUrl: '',
        supabaseAnonKey: '',
        supabaseRedirectUrl: '',
        powerSyncUrl: '',
        sentryDsn: '',
        posthogApiKey: 'phc_123',
        posthogHost: 'https://posthog.example.com',
        revenueCatApplePublicSdkKey: '',
        revenueCatGooglePublicSdkKey: '',
        oneSignalAppId: '',
      ),
      setupPosthog: (config) async {
        capturedConfig = config;
      },
    );

    expect(capturedConfig?.apiKey, 'phc_123');
    expect(capturedConfig?.host, 'https://posthog.example.com');
    expect(capturedConfig?.captureApplicationLifecycleEvents, isTrue);
    expect(capturedConfig?.debug, isFalse);
  });
}
