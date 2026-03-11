import 'dart:convert';

import 'package:flutter_supabase_starter/core/database/powersync_connector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}

void main() {
  late MockSupabaseClient supabaseClient;
  late MockGoTrueClient authClient;

  setUp(() {
    supabaseClient = MockSupabaseClient();
    authClient = MockGoTrueClient();

    when(() => supabaseClient.auth).thenReturn(authClient);
  });

  group('fetchCredentials', () {
    test('returns null when there is no signed in session', () async {
      when(() => authClient.currentSession).thenReturn(null);

      final connector = PowerSyncSupabaseConnector(
        supabaseClient: supabaseClient,
        powerSyncUrl: 'https://example.powersync.app',
      );

      expect(await connector.fetchCredentials(), isNull);
      verifyNever(() => authClient.refreshSession());
    });

    test(
      'returns credentials from the current session when still valid',
      () async {
      final session = buildSession(expiresInSeconds: 3600);
      when(() => authClient.currentSession).thenReturn(session);

      final connector = PowerSyncSupabaseConnector(
        supabaseClient: supabaseClient,
        powerSyncUrl: 'https://example.powersync.app',
      );

      final credentials = await connector.fetchCredentials();

      expect(credentials, isNotNull);
      expect(credentials!.endpoint, 'https://example.powersync.app');
      expect(credentials.token, session.accessToken);
      expect(credentials.userId, session.user.id);
      verifyNever(() => authClient.refreshSession());
      },
    );

    test('refreshes the session when it expires within 60 seconds', () async {
      final expiringSession = buildSession(expiresInSeconds: 30);
      final refreshedSession = buildSession(expiresInSeconds: 3600);
      when(() => authClient.currentSession).thenReturn(expiringSession);
      when(() => authClient.refreshSession()).thenAnswer(
        (_) async => AuthResponse(session: refreshedSession),
      );

      final connector = PowerSyncSupabaseConnector(
        supabaseClient: supabaseClient,
        powerSyncUrl: 'https://example.powersync.app',
      );

      final credentials = await connector.fetchCredentials();

      expect(credentials, isNotNull);
      expect(credentials!.token, refreshedSession.accessToken);
      verify(() => authClient.refreshSession()).called(1);
    });
  });

  group('uploadData', () {
    test(
      'requests batches with a limit of 100 and completes uploaded batches',
      () async {
      final database = MockPowerSyncDatabase();
      const expectedLimit = PowerSyncSupabaseConnector.crudBatchLimit;
      var completedBatches = 0;
      final uploadedCrud = <List<CrudEntry>>[];
      var callCount = 0;

      when(
        () => database.getCrudBatch(
          // keep explicit to lock the batching contract to 100 records
          // ignore: avoid_redundant_argument_values
          limit: expectedLimit,
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return CrudBatch(
            crud: [
              CrudEntry(
                1,
                UpdateType.put,
                'notes',
                'note-1',
                1,
                {'title': 'First'},
              ),
            ],
            haveMore: true,
            complete: ({writeCheckpoint}) async {
              completedBatches++;
            },
          );
        }

        if (callCount == 2) {
          return CrudBatch(
            crud: [
              CrudEntry(
                2,
                UpdateType.patch,
                'notes',
                'note-2',
                2,
                {'title': 'Second'},
              ),
            ],
            haveMore: false,
            complete: ({writeCheckpoint}) async {
              completedBatches++;
            },
          );
        }

        return null;
      });

      final connector = PowerSyncSupabaseConnector(
        supabaseClient: supabaseClient,
        powerSyncUrl: 'https://example.powersync.app',
        uploader: (crud) async => uploadedCrud.add(crud),
      );

      await connector.uploadData(database);

      expect(uploadedCrud, hasLength(2));
      expect(completedBatches, 2);
      verify(
        () => database.getCrudBatch(
          // keep explicit to lock the batching contract to 100 records
          // ignore: avoid_redundant_argument_values
          limit: expectedLimit,
        ),
      ).called(2);
      },
    );
  });
}

Session buildSession({required int expiresInSeconds}) {
  final expiresAt = DateTime.now().toUtc().add(
    Duration(seconds: expiresInSeconds),
  );
  final token = buildJwt(expiresAt);

  return Session(
    accessToken: token,
    expiresIn: expiresInSeconds,
    refreshToken: 'refresh-token',
    tokenType: 'bearer',
    user: User(
      id: 'user-123',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: 'tester@example.com',
      createdAt: DateTime.now().toUtc().toIso8601String(),
    ),
  );
}

String buildJwt(DateTime expiresAt) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': 'user-123',
        'email': 'tester@example.com',
        'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      }),
    ),
  );

  return '$header.$payload.signature';
}
