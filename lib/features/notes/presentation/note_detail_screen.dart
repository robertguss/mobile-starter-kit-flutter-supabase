import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/widgets/async_value_widget.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_controller.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({
    required this.noteId,
    super.key,
  });

  static const routeBasePath = '/note';
  static const noteIdParam = 'id';
  static const routePath = '$routeBasePath/:$noteIdParam';
  static const screenKey = ValueKey<String>('note-detail-screen');

  final String noteId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  static const _saveDebounce = Duration(milliseconds: 500);

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  Timer? _saveTimer;
  NoteModel? _note;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteDetailProvider(widget.noteId));

    return Scaffold(
      key: NoteDetailScreen.screenKey,
      appBar: AppBar(title: Text(context.t.notes.title)),
      body: AsyncValueWidget<NoteModel>(
        value: noteAsync,
        onRetry: () => ref.invalidate(noteDetailProvider(widget.noteId)),
        data: (note) {
          _syncControllers(note);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t.notes.titleLabel),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  onChanged: (_) => _scheduleSave(),
                ),
                const SizedBox(height: 16),
                Text(context.t.notes.bodyLabel),
                const SizedBox(height: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bodyController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    onChanged: (_) => _scheduleSave(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, _saveNote);
  }

  Future<void> _saveNote() async {
    final note = _note;
    if (note == null) {
      return;
    }

    final title = _titleController.text;
    final body = _bodyController.text;
    if (title == note.title && body == note.body) {
      return;
    }

    final updated = await ref.read(notesControllerProvider.notifier).updateNote(
          note.id,
          title: title,
          body: body,
        );
    _note = updated;
    ref.invalidate(noteDetailProvider(widget.noteId));
  }

  void _syncControllers(NoteModel note) {
    if (_note?.id == note.id &&
        _titleController.text == note.title &&
        _bodyController.text == note.body) {
      return;
    }

    _note = note;
    if (_titleController.text != note.title) {
      _titleController.text = note.title;
    }
    if (_bodyController.text != note.body) {
      _bodyController.text = note.body;
    }
  }
}
