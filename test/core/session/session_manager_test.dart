import 'package:flutter_supabase_starter/core/database/powersync_client.dart';
import 'package:flutter_supabase_starter/core/session/session_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}
class _MockPowerSyncClient extends Mock implements AppPowerSyncClient {}
class _MockSupabaseClient extends Mock implements SupabaseClient {}
class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  test('setup logs into SDKs and connects PowerSync in order', () async {
    final database = _MockPowerSyncDatabase();
    final powerSyncClient = _MockPowerSyncClient();
    final supabaseClient = _MockSupabaseClient();
    final authClient = _MockGoTrueClient();
    final events = <String>[];

    when(() => supabaseClient.auth).thenReturn(authClient);
    when(
      () => powerSyncClient.connect(
        database: database,
        supabaseClient: supabaseClient,
        powerSyncUrl: 'https://powersync.example.com',
      ),
    ).thenAnswer((_) async {
      events.add('powersync.connect');
    });

    final manager = buildSessionManager(
      powerSyncClient: powerSyncClient,
      database: database,
      supabaseClient: supabaseClient,
      powerSyncUrl: 'https://powersync.example.com',
      onRevenueCatLogin: (userId) async {
        events.add('revenuecat.login:$userId');
      },
      onOneSignalLogin: (userId) async => events.add('onesignal.login:$userId'),
    );

    await manager.setup('user-123');

    expect(events, [
      'revenuecat.login:user-123',
      'onesignal.login:user-123',
      'powersync.connect',
    ]);
    verify(
      () => powerSyncClient.connect(
        database: database,
        supabaseClient: supabaseClient,
        powerSyncUrl: 'https://powersync.example.com',
      ),
    ).called(1);
  });

  test('teardown clears PowerSync and logs out SDKs in order', () async {
    final database = _MockPowerSyncDatabase();
    final powerSyncClient = _MockPowerSyncClient();
    final supabaseClient = _MockSupabaseClient();
    final authClient = _MockGoTrueClient();
    final events = <String>[];

    when(() => supabaseClient.auth).thenReturn(authClient);
    when(database.disconnectAndClear).thenAnswer((_) async {});
    when(() => powerSyncClient.clear(database)).thenAnswer((_) async {
      events.add('powersync.clear');
    });
    when(authClient.signOut).thenAnswer((_) async {
      events.add('supabase.signout');
    });

    final manager = buildSessionManager(
      powerSyncClient: powerSyncClient,
      database: database,
      supabaseClient: supabaseClient,
      powerSyncUrl: 'https://powersync.example.com',
      onRevenueCatLogout: () async => events.add('revenuecat.logout'),
      onOneSignalLogout: () async => events.add('onesignal.logout'),
    );

    await manager.teardown();

    expect(events, [
      'powersync.clear',
      'revenuecat.logout',
      'onesignal.logout',
      'supabase.signout',
    ]);
    verify(() => powerSyncClient.clear(database)).called(1);
    verify(authClient.signOut).called(1);
  });
}
