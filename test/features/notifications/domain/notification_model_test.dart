import 'package:flutter_supabase_starter/features/notifications/domain/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isAuthorized reflects the current permission status', () {
    const authorized = NotificationPermissionModel(
      status: NotificationPermissionStatus.authorized,
      canRequestPermission: false,
    );
    const denied = NotificationPermissionModel(
      status: NotificationPermissionStatus.denied,
      canRequestPermission: false,
    );

    expect(authorized.isAuthorized, isTrue);
    expect(denied.isAuthorized, isFalse);
  });

  test('copyWith preserves values that are not overridden', () {
    const model = NotificationPermissionModel(
      status: NotificationPermissionStatus.notDetermined,
      canRequestPermission: true,
    );

    final updated = model.copyWith(
      status: NotificationPermissionStatus.denied,
    );

    expect(updated.status, NotificationPermissionStatus.denied);
    expect(updated.canRequestPermission, isTrue);
  });
}
