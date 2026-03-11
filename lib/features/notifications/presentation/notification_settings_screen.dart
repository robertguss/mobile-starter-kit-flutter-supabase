import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static const routePath = '/settings';
  static const screenKey = ValueKey<String>('settings-screen');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.t.settings.title)),
      body: Center(child: Text(context.t.settings.notifications)),
    );
  }
}
