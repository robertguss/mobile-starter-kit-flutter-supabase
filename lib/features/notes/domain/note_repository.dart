import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_repository.g.dart';

abstract class NoteRepository {
  Future<List<NoteModel>> getNotes({int limit = 50, int offset = 0});

  Stream<List<NoteModel>> watchNotes({int limit = 50});

  Future<NoteModel> getNote(String id);

  Future<NoteModel> createNote(String title, String body);

  Future<NoteModel> updateNote(String id, {String? title, String? body});

  Future<void> deleteNote(String id);
}

@Riverpod(keepAlive: true)
NoteRepository noteRepository(Ref ref) {
  throw UnimplementedError(
    'Override noteRepositoryProvider with a concrete implementation.',
  );
}
