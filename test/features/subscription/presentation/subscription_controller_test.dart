import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_repository.dart';
import 'package:flutter_supabase_starter/features/subscription/presentation/subscription_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../domain/mock_subscription_repository.dart';

void main() {
  late MockSubscriptionRepository repository;
  late StreamController<SubscriptionModel> subscriptionController;

  const inactiveSubscription = SubscriptionModel(
    status: SubscriptionStatus.inactive,
    entitlementId: 'pro',
  );
  final activeSubscription = SubscriptionModel(
    status: SubscriptionStatus.active,
    entitlementId: 'pro',
    productId: 'pro_monthly',
    expiresAt: DateTime.utc(2026, 4, 11),
    managementUrl: Uri.parse('https://example.com/manage'),
  );
  const packages = [
    SubscriptionPackageModel(
      identifier: 'pro_monthly',
      title: 'Pro Monthly',
      description: 'Monthly access to premium features',
      priceLabel: r'$9.99',
      billingPeriod: 'month',
    ),
    SubscriptionPackageModel(
      identifier: 'pro_yearly',
      title: 'Pro Yearly',
      description: 'Yearly access to premium features',
      priceLabel: r'$99.99',
      billingPeriod: 'year',
    ),
  ];

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  setUp(() {
    repository = MockSubscriptionRepository();
    subscriptionController = StreamController<SubscriptionModel>.broadcast();

    when(repository.watchSubscription).thenAnswer(
      (_) => subscriptionController.stream,
    );
    when(
      repository.getSubscription,
    ).thenAnswer((_) async => inactiveSubscription);
    when(
      repository.getAvailablePackages,
    ).thenAnswer((_) async => packages);
    when(
      () => repository.purchasePackage('pro_monthly'),
    ).thenAnswer((_) async => activeSubscription);
    when(
      repository.restorePurchases,
    ).thenAnswer((_) async => activeSubscription);
  });

  tearDown(() async {
    await subscriptionController.close();
  });

  test('loads the current subscription and available packages', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(
      subscriptionControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(subscriptionControllerProvider).requireValue;
    expect(state.subscription, inactiveSubscription);
    expect(state.packages, packages);
  });

  test('watchSubscription updates the current subscription', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(
      subscriptionControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    subscriptionController.add(activeSubscription);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(subscriptionControllerProvider).requireValue.subscription,
      activeSubscription,
    );
  });

  test(
    'purchasePackage delegates to the repository and updates state',
    () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(
      subscriptionControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    final result = await container
        .read(subscriptionControllerProvider.notifier)
        .purchasePackage('pro_monthly');

    expect(result, activeSubscription);
    expect(
      container.read(subscriptionControllerProvider).requireValue.subscription,
      activeSubscription,
    );
    verify(() => repository.purchasePackage('pro_monthly')).called(1);
  });

  test(
    'restorePurchases delegates to the repository and updates state',
    () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(
      subscriptionControllerProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    final result = await container
        .read(subscriptionControllerProvider.notifier)
        .restorePurchases();

    expect(result, activeSubscription);
    expect(
      container.read(subscriptionControllerProvider).requireValue.subscription,
      activeSubscription,
    );
    verify(repository.restorePurchases).called(1);
  });
}
