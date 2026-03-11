import 'dart:async';

import 'package:flutter_supabase_starter/features/notifications/domain/notification_model.dart';
import 'package:flutter_supabase_starter/features/notifications/domain/notification_repository.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

typedef PermissionStatusLoader = Future<OSNotificationPermission> Function();
typedef PermissionRequestChecker = Future<bool> Function();
typedef PermissionRequester =
    Future<bool> Function({required bool fallbackToSettings});
typedef PermissionObserverRegistrar = void Function(
  OnNotificationPermissionChangeObserver observer,
);
typedef PermissionObserverRemover = void Function(
  OnNotificationPermissionChangeObserver observer,
);

Future<bool> _defaultRequestPermission({
  required bool fallbackToSettings,
}) {
  return OneSignal.Notifications.requestPermission(fallbackToSettings);
}

class OneSignalNotificationRepository implements NotificationRepository {
  OneSignalNotificationRepository({
    PermissionStatusLoader? permissionStatus,
    PermissionRequestChecker? canRequestPermission,
    PermissionRequester? requestPermission,
    PermissionObserverRegistrar? addPermissionObserver,
    PermissionObserverRemover? removePermissionObserver,
  }) : _permissionStatus =
           permissionStatus ?? OneSignal.Notifications.permissionNative,
       _canRequestPermission =
           canRequestPermission ?? OneSignal.Notifications.canRequest,
       _requestPermission = requestPermission ?? _defaultRequestPermission,
       _addPermissionObserver =
           addPermissionObserver ??
           OneSignal.Notifications.addPermissionObserver,
       _removePermissionObserver =
           removePermissionObserver ??
           OneSignal.Notifications.removePermissionObserver;

  final PermissionStatusLoader _permissionStatus;
  final PermissionRequestChecker _canRequestPermission;
  final PermissionRequester _requestPermission;
  final PermissionObserverRegistrar _addPermissionObserver;
  final PermissionObserverRemover _removePermissionObserver;

  @override
  Future<NotificationPermissionModel> getPermissionStatus() async {
    return NotificationPermissionModel(
      status: _mapPermission(await _permissionStatus()),
      canRequestPermission: await _canRequestPermission(),
    );
  }

  @override
  Future<NotificationPermissionModel> requestPermission() async {
    await _requestPermission(fallbackToSettings: true);
    return getPermissionStatus();
  }

  @override
  Stream<NotificationPermissionModel> watchPermissionStatus() {
    late final StreamController<NotificationPermissionModel> controller;
    late final OnNotificationPermissionChangeObserver observer;

    controller = StreamController<NotificationPermissionModel>.broadcast(
      onListen: () {
        observer = (_) async {
          controller.add(await getPermissionStatus());
        };
        _addPermissionObserver(observer);
      },
      onCancel: () {
        _removePermissionObserver(observer);
      },
    );

    return controller.stream;
  }

  NotificationPermissionStatus _mapPermission(OSNotificationPermission status) {
    return switch (status) {
      OSNotificationPermission.authorized ||
      OSNotificationPermission.provisional ||
      OSNotificationPermission.ephemeral =>
        NotificationPermissionStatus.authorized,
      OSNotificationPermission.denied => NotificationPermissionStatus.denied,
      OSNotificationPermission.notDetermined =>
        NotificationPermissionStatus.notDetermined,
    };
  }
}
