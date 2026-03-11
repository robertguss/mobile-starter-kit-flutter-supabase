import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.note,
    super.key,
    this.onTap,
  });

  final NoteModel note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(note.title),
        subtitle: Text(
          note.body.isEmpty ? note.updatedAt.toIso8601String() : note.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}
