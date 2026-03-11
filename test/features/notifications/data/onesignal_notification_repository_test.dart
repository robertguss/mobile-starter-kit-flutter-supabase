import 'package:flutter_supabase_starter/features/notifications/data/onesignal_notification_repository.dart';
import 'package:flutter_supabase_starter/features/notifications/domain/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() {
  test(
    'getPermissionStatus maps native permission and requestability',
    () async {
    final repository = OneSignalNotificationRepository(
      permissionStatus: () async => OSNotificationPermission.provisional,
      canRequestPermission: () async => false,
      addPermissionObserver: (_) {},
      removePermissionObserver: (_) {},
    );

    final permission = await repository.getPermissionStatus();

    expect(permission.status, NotificationPermissionStatus.authorized);
    expect(permission.canRequestPermission, isFalse);
    },
  );

  test(
    'requestPermission requests with fallbackToSettings and refreshes state',
    () async {
    bool? requestedWithFallback;
    final repository = OneSignalNotificationRepository(
      permissionStatus: () async => OSNotificationPermission.authorized,
      canRequestPermission: () async => false,
      requestPermission: ({required fallbackToSettings}) async {
        requestedWithFallback = fallbackToSettings;
        return true;
      },
      addPermissionObserver: (_) {},
      removePermissionObserver: (_) {},
    );

    final permission = await repository.requestPermission();

    expect(permission.status, NotificationPermissionStatus.authorized);
    expect(permission.canRequestPermission, isFalse);
    expect(requestedWithFallback, isTrue);
    },
  );

  test(
    'watchPermissionStatus relays updates and removes the observer on cancel',
    () async {
    OnNotificationPermissionChangeObserver? observer;
    OnNotificationPermissionChangeObserver? removedObserver;
    final statuses = <OSNotificationPermission>[
      OSNotificationPermission.denied,
      OSNotificationPermission.authorized,
    ];
    var statusIndex = 0;

    final repository = OneSignalNotificationRepository(
      permissionStatus: () async => statuses[statusIndex],
      canRequestPermission: () async => false,
      addPermissionObserver: (registeredObserver) {
        observer = registeredObserver;
      },
      removePermissionObserver: (registeredObserver) {
        removedObserver = registeredObserver;
      },
    );

    final events = <NotificationPermissionModel>[];
    final subscription = repository.watchPermissionStatus().listen(events.add);

    statusIndex = 1;
    observer!(true);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(events.single.status, NotificationPermissionStatus.authorized);
    expect(events.single.canRequestPermission, isFalse);
    expect(removedObserver, same(observer));
    },
  );

  test('maps denied and not determined statuses explicitly', () async {
    final deniedRepository = OneSignalNotificationRepository(
      permissionStatus: () async => OSNotificationPermission.denied,
      canRequestPermission: () async => false,
      addPermissionObserver: (_) {},
      removePermissionObserver: (_) {},
    );
    final pendingRepository = OneSignalNotificationRepository(
      permissionStatus: () async => OSNotificationPermission.notDetermined,
      canRequestPermission: () async => true,
      addPermissionObserver: (_) {},
      removePermissionObserver: (_) {},
    );

    expect(
      (await deniedRepository.getPermissionStatus()).status,
      NotificationPermissionStatus.denied,
    );
    expect(
      (await pendingRepository.getPermissionStatus()).status,
      NotificationPermissionStatus.notDetermined,
    );
  });
}
