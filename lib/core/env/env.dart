class AppEnv {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabaseRedirectUrl,
    required this.powerSyncUrl,
    required this.sentryDsn,
    required this.posthogApiKey,
    required this.posthogHost,
    required this.revenueCatApplePublicSdkKey,
    required this.revenueCatGooglePublicSdkKey,
    required this.oneSignalAppId,
  });

  factory AppEnv.fromEnvironment() {
    return const AppEnv(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      supabaseRedirectUrl: String.fromEnvironment('SUPABASE_REDIRECT_URL'),
      powerSyncUrl: String.fromEnvironment('POWERSYNC_URL'),
      sentryDsn: String.fromEnvironment('SENTRY_DSN'),
      posthogApiKey: String.fromEnvironment('POSTHOG_API_KEY'),
      posthogHost: String.fromEnvironment('POSTHOG_HOST'),
      revenueCatApplePublicSdkKey: String.fromEnvironment(
        'REVENUECAT_APPLE_PUBLIC_SDK_KEY',
      ),
      revenueCatGooglePublicSdkKey: String.fromEnvironment(
        'REVENUECAT_GOOGLE_PUBLIC_SDK_KEY',
      ),
      oneSignalAppId: String.fromEnvironment('ONESIGNAL_APP_ID'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabaseRedirectUrl;
  final String powerSyncUrl;
  final String sentryDsn;
  final String posthogApiKey;
  final String posthogHost;
  final String revenueCatApplePublicSdkKey;
  final String revenueCatGooglePublicSdkKey;
  final String oneSignalAppId;

  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get hasSentryConfig => sentryDsn.isNotEmpty;

  bool get hasPosthogConfig =>
      posthogApiKey.isNotEmpty && posthogHost.isNotEmpty;
}
