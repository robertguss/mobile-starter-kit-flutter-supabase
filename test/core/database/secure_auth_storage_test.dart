import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_supabase_starter/core/database/secure_auth_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockFlutterSecureStorage secureStorage;
  late SecureAuthStorage authStorage;

  setUp(() {
    secureStorage = _MockFlutterSecureStorage();
    authStorage = SecureAuthStorage(
      persistSessionKey: 'session-key',
      secureStorage: secureStorage,
    );
  });

  test('hasAccessToken returns true when a stored session exists', () async {
    when(
      () => secureStorage.read(key: 'session-key'),
    ).thenAnswer((_) async => 'token');

    final result = await authStorage.hasAccessToken();

    expect(result, isTrue);
  });

  test(
    'hasAccessToken returns false when the stored session is empty',
    () async {
    when(
      () => secureStorage.read(key: 'session-key'),
    ).thenAnswer((_) async => '');

    final result = await authStorage.hasAccessToken();

    expect(result, isFalse);
    },
  );

  test('accessToken reads the persisted session', () async {
    when(
      () => secureStorage.read(key: 'session-key'),
    ).thenAnswer((_) async => 'access-token');

    expect(await authStorage.accessToken(), 'access-token');
  });

  test('persistSession writes the session value', () async {
    when(
      () => secureStorage.write(key: 'session-key', value: 'session'),
    ).thenAnswer((_) async {});

    await authStorage.persistSession('session');

    verify(
      () => secureStorage.write(key: 'session-key', value: 'session'),
    ).called(1);
  });

  test('removePersistedSession deletes the stored session', () async {
    when(
      () => secureStorage.delete(key: 'session-key'),
    ).thenAnswer((_) async {});

    await authStorage.removePersistedSession();

    verify(() => secureStorage.delete(key: 'session-key')).called(1);
  });
}
