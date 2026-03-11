import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    required this.message,
    super.key,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.t.common.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
