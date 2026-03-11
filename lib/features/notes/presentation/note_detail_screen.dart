import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class NoteDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.t.notes.title)),
      body: Center(child: Text(noteId)),
    );
  }
}
