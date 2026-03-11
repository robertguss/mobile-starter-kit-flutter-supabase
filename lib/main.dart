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
import 'package:flutter_supabase_starter/core/observability/startup_metrics.dart';
import 'package:flutter_supabase_starter/core/providers/database_providers.dart';
import 'package:flutter_supabase_starter/core/router/app_router.dart';
import 'package:flutter_supabase_starter/core/session/session_manager.dart';
import 'package:flutter_supabase_starter/core/theme/app_theme.dart';
import 'package:flutter_supabase_starter/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_supabase_starter/features/auth/domain/auth_repository.dart';
import 'package:flutter_supabase_starter/features/notes/data/powersync_note_repository.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_repository.dart';
import 'package:flutter_supabase_starter/features/notifications/data/onesignal_notification_repository.dart';
import 'package:flutter_supabase_starter/features/notifications/domain/notification_repository.dart';
import 'package:flutter_supabase_starter/features/subscription/data/revenuecat_subscription_repository.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_repository.dart';
import 'package:flutter_supabase_starter/features/subscription/presentation/subscription_controller.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
      final startupMetrics = StartupMetrics.start();

      await runZonedGuarded(
        () async {
          try {
            final supabaseClient = await startupMetrics.measurePhase(
              'supabase_init',
              () => AppSupabaseClient.initialize(env),
            );
            final powerSyncClient = AppPowerSyncClient();
            final powerSyncDatabase = await startupMetrics.measurePhase(
              'powersync_open',
              powerSyncClient.open,
            );
            final sessionManager = await startupMetrics.measurePhase(
              'dependency_wiring',
              () => buildSessionManager(
                powerSyncClient: powerSyncClient,
                database: powerSyncDatabase,
                supabaseClient: supabaseClient,
                powerSyncUrl: env.powerSyncUrl,
              ),
            );
            final authRepository = SupabaseAuthRepository(
              supabaseClient: supabaseClient,
              sessionManager: sessionManager,
            );
            final noteRepository = PowerSyncNoteRepository(
              database: powerSyncDatabase,
              currentUserId: () => supabaseClient.auth.currentUser?.id,
            );
            final notificationRepository = OneSignalNotificationRepository();
            final subscriptionRepository = RevenueCatSubscriptionRepository();

            await startupMetrics.measurePhase('run_app', () {
              runApp(
                TranslationProvider(
                  child: ProviderScope(
                    observers: const [AppProviderObserver()],
                    overrides: [
                      authRepositoryProvider.overrideWithValue(authRepository),
                      noteRepositoryProvider.overrideWithValue(noteRepository),
                      notificationRepositoryProvider.overrideWithValue(
                        notificationRepository,
                      ),
                      subscriptionRepositoryProvider.overrideWithValue(
                        subscriptionRepository,
                      ),
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
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(() async {
                startupMetrics.recordFirstFrame();
                await startupMetrics.finish();
                await _initializeNonCriticalServices(env);
              }());
            });
          } catch (error, stackTrace) {
            await startupMetrics.finish(
              status: const SpanStatus.internalError(),
            );
            Error.throwWithStackTrace(error, stackTrace);
          }
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

  if (env.hasRevenueCatConfig) {
    try {
      await Purchases.configure(
        PurchasesConfiguration(env.revenueCatPublicSdkKey),
      );
    } on Object {
      // Paywall functionality degrades gracefully if RevenueCat is unavailable.
    }
  }

  if (env.hasOneSignalConfig) {
    try {
      await OneSignal.initialize(env.oneSignalAppId);
    } on Object {
      // Push setup should not block startup.
    }
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(subscriptionControllerProvider);
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
