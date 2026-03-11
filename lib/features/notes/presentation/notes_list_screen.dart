import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/widgets/async_value_widget.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/note_detail_screen.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_controller.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/widgets/note_card.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/widgets/sync_status_indicator.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  static const routePath = '/notes';
  static const screenKey = ValueKey<String>('notes-screen');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesControllerProvider);

    return Scaffold(
      key: screenKey,
      appBar: AppBar(
        title: Text(context.t.notes.title),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: SyncStatusIndicator()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final note = await ref
              .read(notesControllerProvider.notifier)
              .createNote(context.t.notes.newNoteTitle, '');
          if (!context.mounted) {
            return;
          }

          context.go('${NoteDetailScreen.routeBasePath}/${note.id}');
        },
        child: const Icon(Icons.add),
      ),
      body: AsyncValueWidget<List<NoteModel>>(
        value: notes,
        onRetry: ref.read(notesControllerProvider.notifier).refresh,
        data: (items) => RefreshIndicator(
          onRefresh: ref.read(notesControllerProvider.notifier).refresh,
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 160),
                    Center(child: Text(context.t.notes.emptyState)),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  prototypeItem: NoteCard(note: items.first),
                  itemBuilder: (context, index) {
                    final note = items[index];
                    return NoteCard(
                      note: note,
                      onTap: () {
                        context.go('${NoteDetailScreen.routeBasePath}/${note.id}');
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}
