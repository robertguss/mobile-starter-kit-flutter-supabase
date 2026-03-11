// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SubscriptionController)
final subscriptionControllerProvider = SubscriptionControllerProvider._();

final class SubscriptionControllerProvider
    extends
        $AsyncNotifierProvider<SubscriptionController, SubscriptionViewModel> {
  SubscriptionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionControllerHash();

  @$internal
  @override
  SubscriptionController create() => SubscriptionController();
}

String _$subscriptionControllerHash() =>
    r'f7fb63d0f6e4433c6a80348ab828fb007a7cc48e';

abstract class _$SubscriptionController
    extends $AsyncNotifier<SubscriptionViewModel> {
  FutureOr<SubscriptionViewModel> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<SubscriptionViewModel>, SubscriptionViewModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SubscriptionViewModel>,
                SubscriptionViewModel
              >,
              AsyncValue<SubscriptionViewModel>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
