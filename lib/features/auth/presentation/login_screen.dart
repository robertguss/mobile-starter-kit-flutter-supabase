import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const routePath = '/login';
  static const screenKey = ValueKey<String>('login-screen');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.t.app.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.auth.emailLabel),
            const SizedBox(height: 12),
            const TextField(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {},
              child: Text(context.t.auth.sendOtp),
            ),
          ],
        ),
      ),
    );
  }
}
