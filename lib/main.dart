import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/database/powersync_client.dart';
import 'package:flutter_supabase_starter/core/database/supabase_client.dart';
import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:flutter_supabase_starter/core/observability/posthog_config.dart';
import 'package:flutter_supabase_starter/core/observability/provider_observer.dart';
import 'package:flutter_supabase_starter/core/observability/sentry_config.dart';
import 'package:flutter_supabase_starter/core/providers/database_providers.dart';
import 'package:flutter_supabase_starter/core/router/app_router.dart';
import 'package:flutter_supabase_starter/core/session/session_manager.dart';
import 'package:flutter_supabase_starter/core/theme/app_theme.dart';
import 'package:flutter_supabase_starter/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_supabase_starter/features/auth/domain/auth_repository.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = AppEnv.fromEnvironment();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    return false;
  };

  await SentryConfig.initialize(
    env: env,
    appRunner: () async {
      await runZonedGuarded(
        () async {
          final supabaseClient = await AppSupabaseClient.initialize(env);
          final powerSyncDatabase = await AppPowerSyncClient().open(
            supabaseClient: supabaseClient,
            powerSyncUrl: env.powerSyncUrl,
          );
          final sessionManager = SessionManager(
            onTeardown: () async {
              await powerSyncDatabase.disconnectAndClear();
              await supabaseClient.auth.signOut();
            },
          );
          final authRepository = SupabaseAuthRepository(
            supabaseClient: supabaseClient,
            sessionManager: sessionManager,
          );

          runApp(
            TranslationProvider(
              child: ProviderScope(
                observers: const [AppProviderObserver()],
                overrides: [
                  authRepositoryProvider.overrideWithValue(authRepository),
                  sessionManagerProvider.overrideWithValue(sessionManager),
                  supabaseClientProvider.overrideWithValue(supabaseClient),
                  powerSyncDatabaseProvider.overrideWithValue(
                    powerSyncDatabase,
                  ),
                ],
                child: const MyApp(),
              ),
            ),
          );

          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_initializeNonCriticalServices(env));
          });
        },
        (error, stackTrace) {},
      );
    },
  );
}

Future<void> _initializeNonCriticalServices(AppEnv env) async {
  try {
    await PosthogConfig.initialize(env);
  } on Object {
    // Non-critical services should not block startup.
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.t.app.title,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
