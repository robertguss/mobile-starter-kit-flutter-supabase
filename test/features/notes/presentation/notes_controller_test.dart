import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_repository.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../domain/mock_note_repository.dart';

void main() {
  late MockNoteRepository repository;
  late StreamController<List<NoteModel>> notesController;

  final firstNote = NoteModel(
    id: 'note-1',
    userId: 'user-1',
    title: 'First note',
    body: 'Body',
    createdAt: DateTime.utc(2026, 3, 11, 10),
    updatedAt: DateTime.utc(2026, 3, 11, 10),
  );
  final secondNote = NoteModel(
    id: 'note-2',
    userId: 'user-1',
    title: 'Second note',
    body: 'Body 2',
    createdAt: DateTime.utc(2026, 3, 11, 11),
    updatedAt: DateTime.utc(2026, 3, 11, 11),
  );

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

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
    ).thenAnswer((_) async => [firstNote]);
  });

  tearDown(() async {
    await notesController.close();
  });

  test('watchNotes streams note list into controller state', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      notesControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    notesController.add([firstNote]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(notesControllerProvider).asData?.value, [firstNote]);
  });

  test('createNote adds the new note to the current state', () async {
    when(
      () => repository.createNote('Untitled note', ''),
    ).thenAnswer((_) async => secondNote);

    final container = createContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      notesControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    notesController.add([firstNote]);
    await Future<void>.delayed(Duration.zero);

    final created = await container
        .read(notesControllerProvider.notifier)
        .createNote('Untitled note', '');

    expect(created, secondNote);
    expect(
      container.read(notesControllerProvider).asData?.value,
      [secondNote, firstNote],
    );
  });

  test('updateNote modifies the existing note', () async {
    final updatedNote = firstNote.copyWith(title: 'Updated title');
    when(
      () => repository.updateNote(
        'note-1',
        title: 'Updated title',
      ),
    ).thenAnswer((_) async => updatedNote);

    final container = createContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      notesControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    notesController.add([firstNote]);
    await Future<void>.delayed(Duration.zero);

    await container.read(notesControllerProvider.notifier).updateNote(
          'note-1',
          title: 'Updated title',
        );

    expect(
      container.read(notesControllerProvider).asData?.value,
      [updatedNote],
    );
  });

  test('deleteNote removes the note from the current state', () async {
    when(() => repository.deleteNote('note-1')).thenAnswer((_) async {});

    final container = createContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      notesControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    notesController.add([firstNote, secondNote]);
    await Future<void>.delayed(Duration.zero);

    await container.read(notesControllerProvider.notifier).deleteNote('note-1');

    expect(container.read(notesControllerProvider).asData?.value, [secondNote]);
  });

  test('refresh works while offline by reading local notes', () async {
    final container = createContainer();
    addTearDown(container.dispose);
    container.read(notesControllerProvider);

    await container.read(notesControllerProvider.notifier).refresh();

    expect(container.read(notesControllerProvider).asData?.value, [firstNote]);
    verify(() => repository.getNotes()).called(1);
  });
}
