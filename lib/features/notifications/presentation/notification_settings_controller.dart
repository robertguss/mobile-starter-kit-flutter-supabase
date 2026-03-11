import 'dart:async';

import 'package:flutter_supabase_starter/features/notifications/domain/notification_model.dart';
import 'package:flutter_supabase_starter/features/notifications/domain/notification_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_settings_controller.g.dart';

@Riverpod(keepAlive: true)
class NotificationSettingsController extends _$NotificationSettingsController {
  StreamSubscription<NotificationPermissionModel>? _subscription;

  NotificationRepository get _repository =>
      ref.watch(notificationRepositoryProvider);

  @override
  FutureOr<NotificationPermissionModel> build() async {
    final permission = await _repository.getPermissionStatus();
    _subscription ??= _repository.watchPermissionStatus().listen(
      (nextPermission) => state = AsyncData(nextPermission),
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );
    ref.onDispose(() => _subscription?.cancel());
    return permission;
  }

  Future<NotificationPermissionModel> requestPermission() async {
    final permission = await _repository.requestPermission();
    state = AsyncData(permission);
    return permission;
  }
}
