import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/features/notifications/domain/notification_model.dart';
import 'package:flutter_supabase_starter/features/notifications/domain/notification_repository.dart';
import 'package:flutter_supabase_starter/features/notifications/presentation/notification_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../domain/mock_notification_repository.dart';

void main() {
  late MockNotificationRepository repository;
  late StreamController<NotificationPermissionModel> permissionController;

  const initialPermission = NotificationPermissionModel(
    status: NotificationPermissionStatus.notDetermined,
    canRequestPermission: true,
  );
  const deniedPermission = NotificationPermissionModel(
    status: NotificationPermissionStatus.denied,
    canRequestPermission: false,
  );
  const authorizedPermission = NotificationPermissionModel(
    status: NotificationPermissionStatus.authorized,
    canRequestPermission: false,
  );

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  setUp(() {
    repository = MockNotificationRepository();
    permissionController =
        StreamController<NotificationPermissionModel>.broadcast();

    when(repository.watchPermissionStatus).thenAnswer(
      (_) => permissionController.stream,
    );
    when(
      repository.getPermissionStatus,
    ).thenAnswer((_) async => initialPermission);
    when(
      repository.requestPermission,
    ).thenAnswer((_) async => authorizedPermission);
  });

  tearDown(() async {
    await permissionController.close();
  });

  test('loads the current notification permission state', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(
      notificationSettingsControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(notificationSettingsControllerProvider).requireValue,
      initialPermission,
    );
  });

  test('watchPermissionStatus updates the current state', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(
      notificationSettingsControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    permissionController.add(deniedPermission);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(notificationSettingsControllerProvider).requireValue,
      deniedPermission,
    );
  });

  test(
    'requestPermission delegates to the repository and updates state',
    () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(
      notificationSettingsControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    final result = await container
        .read(notificationSettingsControllerProvider.notifier)
        .requestPermission();

    expect(result, authorizedPermission);
    expect(
      container.read(notificationSettingsControllerProvider).requireValue,
      authorizedPermission,
    );
      verify(repository.requestPermission).called(1);
    },
  );
}
