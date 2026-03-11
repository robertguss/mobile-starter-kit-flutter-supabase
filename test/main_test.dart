import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:flutter_supabase_starter/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  test('initializeNonCriticalServices skips disabled SDKs', () async {
    var didInitPosthog = false;
    var didConfigureRevenueCat = false;
    var didInitializeOneSignal = false;

    await app.initializeNonCriticalServices(
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
      initializePosthog: (_) async {
        didInitPosthog = true;
      },
      configureRevenueCat: (_) async {
        didConfigureRevenueCat = true;
      },
      initializeOneSignal: (_) async {
        didInitializeOneSignal = true;
      },
    );

    expect(didInitPosthog, isTrue);
    expect(didConfigureRevenueCat, isFalse);
    expect(didInitializeOneSignal, isFalse);
  });

  test(
    'initializeNonCriticalServices degrades when SDK setup throws',
    () async {
    PurchasesConfiguration? purchasesConfiguration;
    String? oneSignalAppId;

    await app.initializeNonCriticalServices(
      const AppEnv(
        supabaseUrl: '',
        supabaseAnonKey: '',
        supabaseRedirectUrl: '',
        powerSyncUrl: '',
        sentryDsn: '',
        posthogApiKey: 'phc_123',
        posthogHost: 'https://posthog.example.com',
        revenueCatApplePublicSdkKey: 'apple-key',
        revenueCatGooglePublicSdkKey: 'google-key',
        oneSignalAppId: 'onesignal-app-id',
      ),
      initializePosthog: (_) async => throw StateError('posthog'),
      configureRevenueCat: (configuration) async {
        purchasesConfiguration = configuration;
        throw StateError('revenuecat');
      },
      initializeOneSignal: (appId) async {
        oneSignalAppId = appId;
        throw StateError('onesignal');
      },
    );

    expect(purchasesConfiguration?.apiKey, isNotEmpty);
    expect(oneSignalAppId, 'onesignal-app-id');
    },
  );
}
