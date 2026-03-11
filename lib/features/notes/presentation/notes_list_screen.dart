import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  static const routePath = '/notes';
  static const screenKey = ValueKey<String>('notes-screen');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.t.notes.title)),
      body: Center(child: Text(context.t.notes.emptyState)),
    );
  }
}
