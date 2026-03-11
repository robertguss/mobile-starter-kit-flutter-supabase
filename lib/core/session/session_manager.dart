import 'package:flutter_supabase_starter/core/database/powersync_client.dart';
import 'package:flutter_supabase_starter/core/env/env.dart';
import 'package:flutter_supabase_starter/core/providers/database_providers.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:powersync/powersync.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'session_manager.g.dart';

typedef SessionSetup = Future<void> Function(String userId);
typedef SessionTeardown = Future<void> Function();
typedef SessionSdkSetup = Future<void> Function(String userId);
typedef SessionSdkTeardown = Future<void> Function();

class SessionManager {
  SessionManager({
    SessionSetup? onSetup,
    SessionTeardown? onTeardown,
  })  : _onSetup = onSetup,
        _onTeardown = onTeardown;

  final SessionSetup? _onSetup;
  final SessionTeardown? _onTeardown;

  Future<void> setup(String userId) async {
    await _onSetup?.call(userId);
  }

  Future<void> teardown() async {
    await _onTeardown?.call();
  }
}

SessionManager buildSessionManager({
  required AppPowerSyncClient powerSyncClient,
  required PowerSyncDatabase database,
  required SupabaseClient supabaseClient,
  required String powerSyncUrl,
  SessionSdkSetup? onRevenueCatLogin,
  SessionSdkTeardown? onRevenueCatLogout,
  SessionSdkSetup? onOneSignalLogin,
  SessionSdkTeardown? onOneSignalLogout,
}) {
  return SessionManager(
    onSetup: (userId) async {
      await (onRevenueCatLogin ?? _revenueCatLogin)(userId);
      await (onOneSignalLogin ?? OneSignal.login)(userId);
      await powerSyncClient.connect(
        database: database,
        supabaseClient: supabaseClient,
        powerSyncUrl: powerSyncUrl,
      );
    },
    onTeardown: () async {
      await powerSyncClient.clear(database);
      await (onRevenueCatLogout ?? _revenueCatLogout)();
      await (onOneSignalLogout ?? OneSignal.logout)();
      await supabaseClient.auth.signOut();
    },
  );
}

Future<void> _revenueCatLogin(String userId) async {
  await Purchases.logIn(userId);
}

Future<void> _revenueCatLogout() async {
  await Purchases.logOut();
}

@Riverpod(keepAlive: true)
SessionManager sessionManager(Ref ref) {
  final env = AppEnv.fromEnvironment();
  final powerSyncClient = AppPowerSyncClient();
  final database = ref.watch(powerSyncDatabaseProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);

  return buildSessionManager(
    powerSyncClient: powerSyncClient,
    database: database,
    supabaseClient: supabaseClient,
    powerSyncUrl: env.powerSyncUrl,
  );
}
