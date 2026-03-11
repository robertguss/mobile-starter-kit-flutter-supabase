import 'package:flutter_supabase_starter/features/notifications/domain/notification_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_repository.g.dart';

@riverpod
NotificationRepository notificationRepository(Ref ref) {
  throw UnimplementedError('Provide a NotificationRepository implementation.');
}

abstract class NotificationRepository {
  Stream<NotificationPermissionModel> watchPermissionStatus();

  Future<NotificationPermissionModel> getPermissionStatus();

  Future<NotificationPermissionModel> requestPermission();
}
