// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NotificationSettingsController)
final notificationSettingsControllerProvider =
    NotificationSettingsControllerProvider._();

final class NotificationSettingsControllerProvider
    extends
        $AsyncNotifierProvider<
          NotificationSettingsController,
          NotificationPermissionModel
        > {
  NotificationSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationSettingsControllerHash();

  @$internal
  @override
  NotificationSettingsController create() => NotificationSettingsController();
}

String _$notificationSettingsControllerHash() =>
    r'ae4abf46c5d25e37a33e6963f4df1e4fc9437505';

abstract class _$NotificationSettingsController
    extends $AsyncNotifier<NotificationPermissionModel> {
  FutureOr<NotificationPermissionModel> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<NotificationPermissionModel>,
              NotificationPermissionModel
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<NotificationPermissionModel>,
                NotificationPermissionModel
              >,
              AsyncValue<NotificationPermissionModel>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
