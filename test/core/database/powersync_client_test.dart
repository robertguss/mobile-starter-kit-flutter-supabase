import 'package:flutter_supabase_starter/core/database/powersync_client.dart';
import 'package:flutter_supabase_starter/core/database/powersync_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _FakePowerSyncConnector extends Fake
    implements PowerSyncBackendConnector {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePowerSyncConnector());
  });

  group('AppPowerSyncClient', () {
    test(
      'opens the database, initializes it, and connects with the connector',
      () async {
      final database = _MockPowerSyncDatabase();
      final supabaseClient = _MockSupabaseClient();
      final connector = _FakePowerSyncConnector();

      when(database.initialize).thenAnswer((_) async {});
      when(
        () => database.connect(
          connector: any(named: 'connector'),
        ),
      ).thenAnswer((_) async {});

      final client = AppPowerSyncClient(
        databasePathProvider: () async => '/tmp/powersync.db',
        databaseFactory: ({required schema, required path}) {
          expect(schema, same(appPowerSyncSchema));
          expect(path, '/tmp/powersync.db');
          return database;
        },
        connectorFactory: ({required supabaseClient, required powerSyncUrl}) {
          expect(supabaseClient, same(supabaseClient));
          expect(powerSyncUrl, 'https://powersync.example.com');
          return connector;
        },
      );

      final openedDatabase = await client.open(
        supabaseClient: supabaseClient,
        powerSyncUrl: 'https://powersync.example.com',
      );

      expect(openedDatabase, same(database));
      verifyInOrder([
        database.initialize,
        () => database.connect(
          connector: connector,
        ),
      ]);
      verifyNoMoreInteractions(database);
      },
    );

    test('clear disconnects and removes local PowerSync data', () async {
      final database = _MockPowerSyncDatabase();

      when(database.disconnectAndClear).thenAnswer((_) async {});

      final client = AppPowerSyncClient(
        databasePathProvider: () async => '/tmp/powersync.db',
      );

      await client.clear(database);

      verify(database.disconnectAndClear).called(1);
      verifyNoMoreInteractions(database);
    });
  });
}
