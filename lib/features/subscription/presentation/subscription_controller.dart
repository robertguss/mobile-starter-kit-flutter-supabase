import 'dart:async';

import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscription_controller.g.dart';

class SubscriptionViewModel {
  const SubscriptionViewModel({
    required this.subscription,
    required this.packages,
  });

  final SubscriptionModel subscription;
  final List<SubscriptionPackageModel> packages;

  SubscriptionViewModel copyWith({
    SubscriptionModel? subscription,
    List<SubscriptionPackageModel>? packages,
  }) {
    return SubscriptionViewModel(
      subscription: subscription ?? this.subscription,
      packages: packages ?? this.packages,
    );
  }
}

@Riverpod(keepAlive: true)
class SubscriptionController extends _$SubscriptionController {
  StreamSubscription<SubscriptionModel>? _subscription;

  SubscriptionRepository get _repository =>
      ref.watch(subscriptionRepositoryProvider);

  @override
  FutureOr<SubscriptionViewModel> build() async {
    final currentSubscription = await _repository.getSubscription();
    final packages = await _repository.getAvailablePackages();

    _subscription ??= _repository.watchSubscription().listen(
      (subscription) {
        final currentState = state.asData?.value;
        state = AsyncData(
          SubscriptionViewModel(
            subscription: subscription,
            packages: currentState?.packages ?? packages,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );
    ref.onDispose(() => _subscription?.cancel());

    return SubscriptionViewModel(
      subscription: currentSubscription,
      packages: packages,
    );
  }

  Future<SubscriptionModel> purchasePackage(String packageId) async {
    final subscription = await _repository.purchasePackage(packageId);
    _updateSubscription(subscription);
    return subscription;
  }

  Future<SubscriptionModel> restorePurchases() async {
    final subscription = await _repository.restorePurchases();
    _updateSubscription(subscription);
    return subscription;
  }

  void _updateSubscription(SubscriptionModel subscription) {
    final currentState = state.asData?.value;
    state = AsyncData(
      SubscriptionViewModel(
        subscription: subscription,
        packages: currentState?.packages ?? const [],
      ),
    );
  }
}
