import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/providers/database_providers.dart';
import 'package:flutter_supabase_starter/core/session/session_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  test('powerSyncDatabaseProvider requires an override by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(powerSyncDatabaseProvider),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('UnimplementedError'),
        ),
      ),
    );
  });

  test(
    'database providers and sessionManagerProvider resolve with overrides',
    () {
    final database = _MockPowerSyncDatabase();
    final supabaseClient = _MockSupabaseClient();
    final container = ProviderContainer(
      overrides: [
        powerSyncDatabaseProvider.overrideWithValue(database),
        supabaseClientProvider.overrideWithValue(supabaseClient),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(powerSyncDatabaseProvider), same(database));
    expect(container.read(supabaseClientProvider), same(supabaseClient));
    expect(container.read(sessionManagerProvider), isA<SessionManager>());
    },
  );
}
