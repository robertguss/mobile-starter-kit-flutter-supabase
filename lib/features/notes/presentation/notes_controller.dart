import 'dart:async';

import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notes_controller.g.dart';

@riverpod
Future<NoteModel> noteDetail(Ref ref, String noteId) {
  return ref.watch(noteRepositoryProvider).getNote(noteId);
}

@Riverpod(keepAlive: true)
class NotesController extends _$NotesController {
  StreamSubscription<List<NoteModel>>? _subscription;

  NoteRepository get _repository => ref.watch(noteRepositoryProvider);

  @override
  FutureOr<List<NoteModel>> build() {
    _subscription ??= _repository.watchNotes().listen(
      (notes) => state = AsyncData(notes),
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );
    ref.onDispose(() => _subscription?.cancel());
    return const [];
  }

  Future<NoteModel> createNote(String title, String body) async {
    final note = await _repository.createNote(title, body);
    final current = [...state.asData?.value ?? const <NoteModel>[]];
    state = AsyncData([note, ...current.where((item) => item.id != note.id)]);
    return note;
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    final current = [...state.asData?.value ?? const <NoteModel>[]];
    state = AsyncData(current.where((note) => note.id != id).toList());
  }

  Future<void> refresh() async {
    state = AsyncData(await _repository.getNotes());
  }

  Future<NoteModel> updateNote(
    String id, {
    String? title,
    String? body,
  }) async {
    final note = await _repository.updateNote(id, title: title, body: body);
    final current = [...state.asData?.value ?? const <NoteModel>[]];
    state = AsyncData([
      for (final item in current)
        if (item.id == id) note else item,
    ]);
    return note;
  }
}
