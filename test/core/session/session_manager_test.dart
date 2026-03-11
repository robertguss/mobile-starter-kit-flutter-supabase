import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/providers/database_providers.dart';
import 'package:flutter_supabase_starter/core/session/session_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart';

class _MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}

void main() {
  test('teardown clears the local PowerSync database', () async {
    final database = _MockPowerSyncDatabase();
    when(database.disconnectAndClear).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        powerSyncDatabaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(container.dispose);

    final manager = container.read(sessionManagerProvider);
    await manager.teardown();

    verify(database.disconnectAndClear).called(1);
    verifyNoMoreInteractions(database);
  });
}
