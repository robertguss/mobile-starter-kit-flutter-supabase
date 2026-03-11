import 'dart:async';

import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef SentryInitializer = Future<void> Function(
  FlutterOptionsConfiguration optionsConfiguration, {
  AppRunner? appRunner,
});

class SentryConfig {
  const SentryConfig._();

  static Future<void> initialize({
    required AppEnv env,
    required FutureOr<void> Function() appRunner,
    SentryInitializer? initializeSentry,
  }) async {
    if (!env.hasSentryConfig) {
      await appRunner();
      return;
    }

    await (initializeSentry ?? SentryFlutter.init)(
      (options) {
        options
          ..dsn = env.sentryDsn
          ..tracesSampleRate = 1.0
          ..sendDefaultPii = false
          ..attachScreenshot = false
          ..enableAppLifecycleBreadcrumbs = true;
      },
      appRunner: appRunner,
    );
  }
}
