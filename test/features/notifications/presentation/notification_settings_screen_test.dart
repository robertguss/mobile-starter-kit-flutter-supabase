import 'dart:async';

import 'package:flutter_supabase_starter/features/notifications/domain/notification_model.dart';
import 'package:flutter_supabase_starter/features/notifications/domain/notification_repository.dart';
import 'package:flutter_supabase_starter/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
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

  List<Object> createOverrides() {
    return [
      notificationRepositoryProvider.overrideWithValue(repository),
    ];
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

  testWidgets('renders the request permission CTA and requests access', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      home: const NotificationSettingsScreen(),
      overrides: createOverrides(),
    );
    addTearDown(container.dispose);

    expect(find.byKey(NotificationSettingsScreen.screenKey), findsOneWidget);
    expect(find.text('Enable notifications'), findsOneWidget);

    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();

    verify(repository.requestPermission).called(1);
    expect(
      find.text('Notifications are enabled for this device.'),
      findsWidgets,
    );
  });

  testWidgets('renders the denied state copy', (tester) async {
    when(
      repository.getPermissionStatus,
    ).thenAnswer((_) async => deniedPermission);

    final container = await pumpApp(
      tester,
      home: const NotificationSettingsScreen(),
      overrides: createOverrides(),
    );
    addTearDown(container.dispose);

    expect(
      find.text('Notifications are off. Enable them in system settings.'),
      findsWidgets,
    );
  });

  testWidgets('stream updates refresh the rendered permission state', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      home: const NotificationSettingsScreen(),
      overrides: createOverrides(),
    );
    addTearDown(container.dispose);

    permissionController.add(authorizedPermission);
    await tester.pumpAndSettle();

    expect(
      find.text('Notifications are enabled for this device.'),
      findsWidgets,
    );
  });
}
