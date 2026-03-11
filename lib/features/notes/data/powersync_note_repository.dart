import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_repository.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

typedef CurrentUserId = String? Function();
typedef NoteIdGenerator = String Function();
typedef CurrentTime = DateTime Function();

class PowerSyncNoteRepository implements NoteRepository {
  PowerSyncNoteRepository({
    required PowerSyncDatabase database,
    required CurrentUserId currentUserId,
    NoteIdGenerator? idGenerator,
    CurrentTime? now,
  })  : _database = database,
        _currentUserId = currentUserId,
        _idGenerator = idGenerator ?? const Uuid().v4,
        _now = now ?? DateTime.now;

  static const _baseSelect =
      'SELECT id, user_id, title, body, created_at, updated_at FROM notes';

  final PowerSyncDatabase _database;
  final CurrentUserId _currentUserId;
  final NoteIdGenerator _idGenerator;
  final CurrentTime _now;

  @override
  Future<NoteModel> createNote(String title, String body) async {
    final userId = _requireCurrentUserId();
    final noteId = _idGenerator();
    final timestamp = _now().toUtc().toIso8601String();

    await _database.execute(
      'INSERT INTO notes (id, user_id, title, body, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [noteId, userId, title, body, timestamp, timestamp],
    );

    return getNote(noteId);
  }

  @override
  Future<void> deleteNote(String id) {
    return _database.execute('DELETE FROM notes WHERE id = ?', [id]);
  }

  @override
  Future<NoteModel> getNote(String id) async {
    final row = await _database.getOptional(
      '$_baseSelect WHERE id = ? LIMIT 1',
      [id],
    );
    if (row == null) {
      throw StateError('Note $id was not found.');
    }

    return _mapRow(row);
  }

  @override
  Future<List<NoteModel>> getNotes({int limit = 50, int offset = 0}) async {
    final rows = await _database.getAll(
      '$_baseSelect ORDER BY datetime(created_at) DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return rows.map(_mapRow).toList(growable: false);
  }

  @override
  Future<NoteModel> updateNote(String id, {String? title, String? body}) async {
    final existing = await getNote(id);
    final timestamp = _now().toUtc().toIso8601String();

    await _database.execute(
      'UPDATE notes SET title = ?, body = ?, updated_at = ? WHERE id = ?',
      [
        title ?? existing.title,
        body ?? existing.body,
        timestamp,
        id,
      ],
    );

    return getNote(id);
  }

  @override
  Stream<List<NoteModel>> watchNotes({int limit = 50}) {
    return _database
        .watch(
          '$_baseSelect ORDER BY datetime(created_at) DESC LIMIT ?',
          parameters: [limit],
        )
        .map((rows) => rows.map(_mapRow).toList(growable: false));
  }

  NoteModel _mapRow(Map<String, Object?> row) {
    return NoteModel(
      id: _readString(row, 'id'),
      userId: _readString(row, 'user_id'),
      title: _readString(row, 'title'),
      body: (row['body'] as String?) ?? '',
      createdAt: DateTime.parse(_readString(row, 'created_at')).toUtc(),
      updatedAt: DateTime.parse(_readString(row, 'updated_at')).toUtc(),
    );
  }

  String _requireCurrentUserId() {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('A signed-in user is required to create notes.');
    }

    return userId;
  }

  String _readString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! String) {
      throw StateError('Expected $key to be a String.');
    }

    return value;
  }
}
