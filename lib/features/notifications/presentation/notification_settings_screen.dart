import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/widgets/async_value_widget.dart';
import 'package:flutter_supabase_starter/features/notifications/domain/notification_model.dart';
import 'package:flutter_supabase_starter/features/notifications/presentation/notification_settings_controller.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const routePath = '/settings';
  static const screenKey = ValueKey<String>('settings-screen');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(notificationSettingsControllerProvider);

    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.t.settings.title)),
      body: AsyncValueWidget(
        value: permissionAsync,
        onRetry: () => ref.invalidate(notificationSettingsControllerProvider),
        data: (permission) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t.settings.notifications,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(_statusLabel(context, permission)),
                const SizedBox(height: 24),
                if (permission.isAuthorized)
                  Text(context.t.settings.notificationsEnabled)
                else if (permission.canRequestPermission)
                  FilledButton(
                    onPressed:
                        () => ref
                            .read(
                              notificationSettingsControllerProvider.notifier,
                            )
                            .requestPermission(),
                    child: Text(context.t.settings.enableNotifications),
                  )
                else
                  Text(context.t.settings.notificationsDenied),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(
    BuildContext context,
    NotificationPermissionModel permission,
  ) {
    return switch (permission.status) {
      NotificationPermissionStatus.authorized =>
        context.t.settings.notificationsEnabled,
      NotificationPermissionStatus.denied =>
        context.t.settings.notificationsDenied,
      NotificationPermissionStatus.notDetermined =>
        context.t.settings.notificationsNotDetermined,
    };
  }
}
