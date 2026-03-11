import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/providers/connectivity_provider.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_repository.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/note_detail_screen.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_list_screen.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline note creation survives reconnect and synced snapshot',
      (tester) async {
    final connectivityController =
        StreamController<ConnectivityStatus>.broadcast();
    final repository = _FakeOfflineSyncNoteRepository();
    final router = GoRouter(
      initialLocation: NotesListScreen.routePath,
      routes: [
        GoRoute(
          path: NotesListScreen.routePath,
          builder: (context, state) => const NotesListScreen(),
        ),
        GoRoute(
          path: NoteDetailScreen.routePath,
          builder: (context, state) => NoteDetailScreen(
            noteId: state.pathParameters[NoteDetailScreen.noteIdParam]!,
          ),
        ),
      ],
    );

    addTearDown(connectivityController.close);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repository),
          connectivityStatusProvider.overrideWith(
            (ref) => connectivityController.stream,
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );

    connectivityController.add(ConnectivityStatus.offline);
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('No notes yet.'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byKey(NoteDetailScreen.screenKey), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Offline draft',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'Created while offline.',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    router.go(NotesListScreen.routePath);
    await tester.pumpAndSettle();

    expect(find.text('Offline draft'), findsOneWidget);
    expect(repository.pendingSyncCount, 1);

    connectivityController.add(ConnectivityStatus.online);
    repository.completeSync();
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Offline draft'), findsOneWidget);
    expect(find.text('Created while offline.'), findsOneWidget);
    expect(repository.pendingSyncCount, 0);
    expect(repository.lastSyncedNote?.title, 'Offline draft');
  });
}

class _FakeOfflineSyncNoteRepository implements NoteRepository {
  final _notes = <String, NoteModel>{};
  final _notesController = StreamController<List<NoteModel>>.broadcast();
  final _pendingSyncIds = <String>{};

  int _idCounter = 0;
  NoteModel? lastSyncedNote;

  int get pendingSyncCount => _pendingSyncIds.length;

  @override
  Future<NoteModel> createNote(String title, String body) async {
    final now = DateTime.utc(2026, 3, 11, 12, ++_idCounter);
    final note = NoteModel(
      id: 'note-$_idCounter',
      userId: 'user-1',
      title: title,
      body: body,
      createdAt: now,
      updatedAt: now,
    );
    _notes[note.id] = note;
    _pendingSyncIds.add(note.id);
    _emit();
    return note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.remove(id);
    _pendingSyncIds.remove(id);
    _emit();
  }

  @override
  Future<NoteModel> getNote(String id) async {
    final note = _notes[id];
    if (note == null) {
      throw StateError('Unknown note: $id');
    }
    return note;
  }

  @override
  Future<List<NoteModel>> getNotes({int limit = 50, int offset = 0}) async {
    return _sortedNotes().skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<NoteModel> updateNote(String id, {String? title, String? body}) async {
    final current = _notes[id];
    if (current == null) {
      throw StateError('Unknown note: $id');
    }

    final updated = current.copyWith(
      title: title ?? current.title,
      body: body ?? current.body,
      updatedAt: current.updatedAt.add(const Duration(minutes: 1)),
    );
    _notes[id] = updated;
    _pendingSyncIds.add(id);
    _emit();
    return updated;
  }

  @override
  Stream<List<NoteModel>> watchNotes({int limit = 50}) async* {
    yield _sortedNotes().take(limit).toList(growable: false);
    yield* _notesController.stream.map(
      (notes) => notes.take(limit).toList(growable: false),
    );
  }

  void completeSync() {
    if (_pendingSyncIds.isEmpty) {
      return;
    }

    lastSyncedNote = _notes[_pendingSyncIds.last];
    _pendingSyncIds.clear();
    _emit();
  }

  void _emit() {
    _notesController.add(_sortedNotes());
  }

  List<NoteModel> _sortedNotes() {
    final notes = _notes.values.toList()..sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );
    return notes;
  }
}
