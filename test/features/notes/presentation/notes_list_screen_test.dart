import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/core/providers/connectivity_provider.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_repository.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/note_detail_screen.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../domain/mock_note_repository.dart';

void main() {
  late MockNoteRepository repository;
  late StreamController<List<NoteModel>> notesController;

  final sampleNote = NoteModel(
    id: 'note-1',
    userId: 'user-1',
    title: 'First note',
    body: 'Body',
    createdAt: DateTime.utc(2026, 3, 11, 10),
    updatedAt: DateTime.utc(2026, 3, 11, 10),
  );

  setUp(() {
    repository = MockNoteRepository();
    notesController = StreamController<List<NoteModel>>.broadcast();
    when(() => repository.watchNotes(limit: any(named: 'limit'))).thenAnswer(
      (_) => notesController.stream,
    );
    when(
      () => repository.getNotes(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => [sampleNote]);
    when(
      () => repository.createNote('Untitled note', ''),
    ).thenAnswer((_) async => sampleNote);
  });

  tearDown(() async {
    await notesController.close();
  });

  GoRouter buildRouter() {
    return GoRouter(
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
  }

  testWidgets('renders list of notes', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
      ],
    );
    addTearDown(container.dispose);

    notesController.add([sampleNote]);
    await tester.pumpAndSettle();

    expect(find.text('First note'), findsOneWidget);
  });

  testWidgets('empty state shown when no notes', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
      ],
    );
    addTearDown(container.dispose);

    notesController.add(const []);
    await tester.pumpAndSettle();

    expect(find.text('No notes yet.'), findsOneWidget);
  });

  testWidgets('pull-to-refresh triggers sync', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
      ],
    );
    addTearDown(container.dispose);

    notesController.add([sampleNote]);
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => repository.getNotes()).called(1);
  });

  testWidgets('FAB navigates to create', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
      ],
    );
    addTearDown(container.dispose);

    notesController.add(const []);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byKey(NoteDetailScreen.screenKey), findsOneWidget);
  });

  testWidgets('sync status indicator shows connectivity state', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.offline),
        ),
      ],
    );
    addTearDown(container.dispose);

    notesController.add(const []);
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
  });
}
