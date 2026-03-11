import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

class PosthogConfig {
  const PosthogConfig._();

  static Future<void> initialize(AppEnv env) async {
    if (!env.hasPosthogConfig) {
      return;
    }

    final config = PostHogConfig(env.posthogApiKey)
      ..host = env.posthogHost
      ..captureApplicationLifecycleEvents = true
      ..debug = false;

    await Posthog().setup(config);
  }
}
