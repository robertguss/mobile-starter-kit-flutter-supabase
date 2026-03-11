import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/widgets/error_screen.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    required this.value,
    required this.data,
    super.key,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      error: (error, stackTrace) => ErrorScreen(
        message: error.toString(),
        onRetry: onRetry,
      ),
      loading: () => Center(child: Text(context.t.common.loading)),
    );
  }
}
