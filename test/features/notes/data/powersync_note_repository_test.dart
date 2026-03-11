import 'package:flutter_supabase_starter/features/notes/data/powersync_note_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class _MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}

void main() {
  sqlite.ResultSet emptyResultSet() {
    return sqlite.ResultSet(const [], null, const []);
  }

  sqlite.Row row(Map<String, Object?> values) {
    final columns = values.keys.toList(growable: false);
    final rowValues = values.values.toList(growable: false);
    return sqlite.Row(
      sqlite.ResultSet(columns, null, [rowValues]),
      rowValues,
    );
  }

  test('getNotes queries local PowerSync SQL with pagination', () async {
    final database = _MockPowerSyncDatabase();
    when(
      () => database.getAll(any(), any()),
    ).thenAnswer((_) async => emptyResultSet());

    final repository = PowerSyncNoteRepository(
      database: database,
      currentUserId: () => 'user-1',
      idGenerator: () => 'generated-id',
      now: () => DateTime.utc(2026, 3, 11, 12),
    );

    await repository.getNotes();

    verify(
      () => database.getAll(
        'SELECT id, user_id, title, body, created_at, updated_at '
        'FROM notes ORDER BY datetime(created_at) DESC LIMIT ? OFFSET ?',
        [50, 0],
      ),
    ).called(1);
  });

  test(
    'createNote inserts the generated row into local PowerSync SQL',
    () async {
    final database = _MockPowerSyncDatabase();
    when(
      () => database.execute(any(), any()),
    ).thenAnswer((_) async => emptyResultSet());
    when(
      () => database.getOptional(any(), any()),
    ).thenAnswer(
      (_) async => row({
        'id': 'generated-id',
        'user_id': 'user-1',
        'title': 'Untitled note',
        'body': '',
        'created_at': '2026-03-11T12:00:00.000Z',
        'updated_at': '2026-03-11T12:00:00.000Z',
      }),
    );

    final repository = PowerSyncNoteRepository(
      database: database,
      currentUserId: () => 'user-1',
      idGenerator: () => 'generated-id',
      now: () => DateTime.utc(2026, 3, 11, 12),
    );

    await repository.createNote('Untitled note', '');

    verify(
      () => database.execute(
        'INSERT INTO notes (id, user_id, title, body, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          'generated-id',
          'user-1',
          'Untitled note',
          '',
          '2026-03-11T12:00:00.000Z',
          '2026-03-11T12:00:00.000Z',
        ],
      ),
    ).called(1);
  });

  test('deleteNote removes the note from local PowerSync SQL', () async {
    final database = _MockPowerSyncDatabase();
    when(
      () => database.execute(any(), any()),
    ).thenAnswer((_) async => emptyResultSet());

    final repository = PowerSyncNoteRepository(
      database: database,
      currentUserId: () => 'user-1',
      idGenerator: () => 'generated-id',
      now: () => DateTime.utc(2026, 3, 11, 12),
    );

    await repository.deleteNote('note-1');

    verify(
      () => database.execute(
        'DELETE FROM notes WHERE id = ?',
        ['note-1'],
      ),
    ).called(1);
  });
}
