import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CrudUploader = Future<void> Function(List<CrudEntry> crud);

class PowerSyncSupabaseConnector extends PowerSyncBackendConnector {
  PowerSyncSupabaseConnector({
    required SupabaseClient supabaseClient,
    required this.powerSyncUrl,
    CrudUploader? uploader,
  })  : _supabaseClient = supabaseClient,
        _uploader = uploader ?? _noopUploader;

  static const crudBatchLimit = 100;

  final SupabaseClient _supabaseClient;
  final String powerSyncUrl;
  final CrudUploader _uploader;

  static Future<void> _noopUploader(List<CrudEntry> crud) async {}

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    var session = _supabaseClient.auth.currentSession;
    if (session == null) {
      return null;
    }

    if (_expiresWithinRefreshWindow(session)) {
      final refreshed = await _supabaseClient.auth.refreshSession();
      session = refreshed.session ?? _supabaseClient.auth.currentSession;
      if (session == null) {
        return null;
      }
    }

    return PowerSyncCredentials(
      endpoint: powerSyncUrl,
      token: session.accessToken,
      userId: session.user.id,
      expiresAt: _sessionExpiry(session),
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    while (true) {
      // PowerSync recommends explicit batching to bound upload memory usage.
      // ignore: avoid_redundant_argument_values
      final batch = await database.getCrudBatch(limit: crudBatchLimit);
      if (batch == null) {
        return;
      }

      await _uploader(batch.crud);
      await batch.complete();

      if (!batch.haveMore) {
        return;
      }
    }
  }

  bool _expiresWithinRefreshWindow(Session session) {
    final expiresAt = _sessionExpiry(session);
    if (expiresAt == null) {
      return false;
    }

    return expiresAt.isBefore(
      DateTime.now().toUtc().add(const Duration(seconds: 60)),
    );
  }

  DateTime? _sessionExpiry(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      expiresAt * 1000,
    );
  }
}
