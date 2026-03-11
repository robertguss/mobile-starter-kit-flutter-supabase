import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:flutter_supabase_starter/core/observability/sentry_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('runs appRunner directly when Sentry is not configured', () async {
    var didRunApp = false;
    var didInitializeSentry = false;

    await SentryConfig.initialize(
      env: const AppEnv(
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
      appRunner: () async {
        didRunApp = true;
      },
      initializeSentry: (_, {appRunner}) async {
        didInitializeSentry = true;
        await appRunner?.call();
      },
    );

    expect(didRunApp, isTrue);
    expect(didInitializeSentry, isFalse);
  });

  test('configures Sentry options when a DSN is present', () async {
    FlutterOptionsConfiguration? capturedConfiguration;
    AppRunner? capturedRunner;

    await SentryConfig.initialize(
      env: const AppEnv(
        supabaseUrl: '',
        supabaseAnonKey: '',
        supabaseRedirectUrl: '',
        powerSyncUrl: '',
        sentryDsn: 'https://example@sentry.io/1',
        posthogApiKey: '',
        posthogHost: '',
        revenueCatApplePublicSdkKey: '',
        revenueCatGooglePublicSdkKey: '',
        oneSignalAppId: '',
      ),
      appRunner: () async {},
      initializeSentry: (optionsConfiguration, {appRunner}) async {
        capturedConfiguration = optionsConfiguration;
        capturedRunner = appRunner;
      },
    );

    final options = SentryFlutterOptions();
    await capturedConfiguration!(options);

    expect(capturedRunner, isNotNull);
    expect(options.dsn, 'https://example@sentry.io/1');
    expect(options.tracesSampleRate, 1.0);
    expect(options.sendDefaultPii, isFalse);
    expect(options.attachScreenshot, isFalse);
    expect(options.enableAppLifecycleBreadcrumbs, isTrue);
  });
}
