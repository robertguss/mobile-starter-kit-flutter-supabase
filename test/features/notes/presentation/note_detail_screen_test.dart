import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_repository.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/note_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../domain/mock_note_repository.dart';

void main() {
  late MockNoteRepository repository;

  final sampleNote = NoteModel(
    id: 'note-1',
    userId: 'user-1',
    title: 'First note',
    body: 'Body text',
    createdAt: DateTime.utc(2026, 3, 11, 10),
    updatedAt: DateTime.utc(2026, 3, 11, 10),
  );

  setUp(() {
    repository = MockNoteRepository();
    when(
      () => repository.watchNotes(limit: any(named: 'limit')),
    ).thenAnswer((_) => Stream.value([sampleNote]));
    when(
      () => repository.getNote('note-1'),
    ).thenAnswer((_) async => sampleNote);
    when(
      () => repository.updateNote(
        'note-1',
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((invocation) async {
      return sampleNote.copyWith(
        title: invocation.namedArguments[#title] as String? ?? sampleNote.title,
        body: invocation.namedArguments[#body] as String? ?? sampleNote.body,
      );
    });
  });

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '${NoteDetailScreen.routeBasePath}/note-1',
      routes: [
        GoRoute(
          path: NoteDetailScreen.routePath,
          builder: (context, state) => NoteDetailScreen(
            noteId: state.pathParameters[NoteDetailScreen.noteIdParam]!,
          ),
        ),
      ],
    );
  }

  testWidgets('renders the current note title and body', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'First note'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Body text'), findsOneWidget);
  });

  testWidgets('auto-saves title edits after a debounce', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Updated title');
    await tester.pump(const Duration(milliseconds: 700));

    verify(
      () => repository.updateNote(
        'note-1',
        title: 'Updated title',
        body: 'Body text',
      ),
    ).called(1);
  });

  testWidgets('auto-saves body edits after a debounce', (tester) async {
    final container = await pumpApp(
      tester,
      router: buildRouter(),
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'Updated body');
    await tester.pump(const Duration(milliseconds: 700));

    verify(
      () => repository.updateNote(
        'note-1',
        title: 'First note',
        body: 'Updated body',
      ),
    ).called(1);
  });
}
