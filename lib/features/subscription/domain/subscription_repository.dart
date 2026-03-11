import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscription_repository.g.dart';

@riverpod
SubscriptionRepository subscriptionRepository(Ref ref) {
  throw UnimplementedError('Provide a SubscriptionRepository implementation.');
}

abstract class SubscriptionRepository {
  Stream<SubscriptionModel> watchSubscription();

  Future<SubscriptionModel> getSubscription();

  Future<List<SubscriptionPackageModel>> getAvailablePackages();

  Future<SubscriptionModel> purchasePackage(String packageId);

  Future<SubscriptionModel> restorePurchases();
}
