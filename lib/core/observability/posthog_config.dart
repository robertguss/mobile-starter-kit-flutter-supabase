import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

typedef PosthogSetup = Future<void> Function(PostHogConfig config);

class PosthogConfig {
  const PosthogConfig._();

  static Future<void> initialize(
    AppEnv env, {
    PosthogSetup? setupPosthog,
  }) async {
    if (!env.hasPosthogConfig) {
      return;
    }

    final config = PostHogConfig(env.posthogApiKey)
      ..host = env.posthogHost
      ..captureApplicationLifecycleEvents = true
      ..debug = false;

    await (setupPosthog ?? _setupPosthog)(config);
  }

  static Future<void> _setupPosthog(PostHogConfig config) {
    return Posthog().setup(config);
  }
}
