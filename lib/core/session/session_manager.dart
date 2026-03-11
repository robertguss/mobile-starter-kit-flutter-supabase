import 'package:flutter_supabase_starter/core/providers/database_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_manager.g.dart';

typedef SessionSetup = Future<void> Function(String userId);
typedef SessionTeardown = Future<void> Function();

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

@Riverpod(keepAlive: true)
SessionManager sessionManager(Ref ref) {
  final database = ref.watch(powerSyncDatabaseProvider);
  return SessionManager(onTeardown: database.disconnectAndClear);
}
