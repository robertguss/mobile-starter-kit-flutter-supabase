import 'package:flutter_supabase_starter/core/database/powersync_connector.dart';
import 'package:flutter_supabase_starter/core/database/powersync_schema.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef DatabasePathProvider = Future<String> Function();
typedef PowerSyncDatabaseFactory =
    PowerSyncDatabase Function({required Schema schema, required String path});
typedef PowerSyncConnectorFactory =
    PowerSyncBackendConnector Function({
      required SupabaseClient supabaseClient,
      required String powerSyncUrl,
    });

class AppPowerSyncClient {
  AppPowerSyncClient({
    DatabasePathProvider? databasePathProvider,
    PowerSyncDatabaseFactory? databaseFactory,
    PowerSyncConnectorFactory? connectorFactory,
  })  : _databasePathProvider =
            databasePathProvider ?? _defaultDatabasePathProvider,
        _databaseFactory = databaseFactory ?? _defaultDatabaseFactory,
        _connectorFactory = connectorFactory ?? _defaultConnectorFactory;

  static const databaseFileName = 'powersync.sqlite';

  final DatabasePathProvider _databasePathProvider;
  final PowerSyncDatabaseFactory _databaseFactory;
  final PowerSyncConnectorFactory _connectorFactory;

  Future<PowerSyncDatabase> open({
    required SupabaseClient supabaseClient,
    required String powerSyncUrl,
  }) async {
    final databasePath = await _databasePathProvider();
    final database = _databaseFactory(
      schema: appPowerSyncSchema,
      path: databasePath,
    );

    await database.initialize();
    await database.connect(
      connector: _connectorFactory(
        supabaseClient: supabaseClient,
        powerSyncUrl: powerSyncUrl,
      ),
    );

    return database;
  }

  Future<void> clear(PowerSyncDatabase database) {
    return database.disconnectAndClear();
  }

  static Future<String> _defaultDatabasePathProvider() async {
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, databaseFileName);
  }

  static PowerSyncDatabase _defaultDatabaseFactory({
    required Schema schema,
    required String path,
  }) {
    return PowerSyncDatabase(schema: schema, path: path);
  }

  static PowerSyncBackendConnector _defaultConnectorFactory({
    required SupabaseClient supabaseClient,
    required String powerSyncUrl,
  }) {
    return PowerSyncSupabaseConnector(
      supabaseClient: supabaseClient,
      powerSyncUrl: powerSyncUrl,
    );
  }
}
