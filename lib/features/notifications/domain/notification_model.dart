class NotificationPermissionModel {
  const NotificationPermissionModel({
    required this.status,
    required this.canRequestPermission,
  });

  final NotificationPermissionStatus status;
  final bool canRequestPermission;

  bool get isAuthorized => status == NotificationPermissionStatus.authorized;

  NotificationPermissionModel copyWith({
    NotificationPermissionStatus? status,
    bool? canRequestPermission,
  }) {
    return NotificationPermissionModel(
      status: status ?? this.status,
      canRequestPermission:
          canRequestPermission ?? this.canRequestPermission,
    );
  }
}

enum NotificationPermissionStatus { notDetermined, denied, authorized }
