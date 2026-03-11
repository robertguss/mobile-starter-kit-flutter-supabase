import 'dart:async';

import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_repository.dart';
import 'package:flutter_supabase_starter/features/subscription/presentation/paywall_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
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
  );
  const packages = [
    SubscriptionPackageModel(
      identifier: 'pro_monthly',
      title: 'Pro Monthly',
      description: 'Monthly access',
      priceLabel: r'$9.99',
      billingPeriod: 'month',
    ),
  ];

  List<Object> createOverrides() {
    return [
      subscriptionRepositoryProvider.overrideWithValue(repository),
    ];
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

  testWidgets('renders available packages and purchases a plan', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      home: const PaywallScreen(),
      overrides: createOverrides(),
    );
    addTearDown(container.dispose);

    expect(find.byKey(PaywallScreen.screenKey), findsOneWidget);
    expect(find.text('Pro Monthly'), findsOneWidget);

    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    verify(() => repository.purchasePackage('pro_monthly')).called(1);
    expect(find.text('Pro is active'), findsOneWidget);
  });

  testWidgets('renders an empty state when no packages are available', (
    tester,
  ) async {
    when(repository.getAvailablePackages).thenAnswer((_) async => const []);

    final container = await pumpApp(
      tester,
      home: const PaywallScreen(),
      overrides: createOverrides(),
    );
    addTearDown(container.dispose);

    expect(
      find.text('No subscription packages are available right now.'),
      findsOneWidget,
    );
  });

  testWidgets('restore purchases delegates to the controller', (tester) async {
    final container = await pumpApp(
      tester,
      home: const PaywallScreen(),
      overrides: createOverrides(),
    );
    addTearDown(container.dispose);

    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();

    verify(repository.restorePurchases).called(1);
    expect(find.text('Pro is active'), findsOneWidget);
  });
}
