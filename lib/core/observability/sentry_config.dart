import 'dart:async';

import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryConfig {
  const SentryConfig._();

  static Future<void> initialize({
    required AppEnv env,
    required FutureOr<void> Function() appRunner,
  }) async {
    if (!env.hasSentryConfig) {
      await appRunner();
      return;
    }

    await SentryFlutter.init(
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
