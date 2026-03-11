import 'package:flutter_supabase_starter/features/subscription/data/revenuecat_subscription_repository.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  test('getAvailablePackages maps the current offering packages', () async {
    final repository = RevenueCatSubscriptionRepository(
      getOfferings: () async => Offerings(
        {'default': _offering(packages: [_package(id: 'pro_monthly')])},
        current: _offering(packages: [_package(id: 'pro_monthly')]),
      ),
    );

    final packages = await repository.getAvailablePackages();

    expect(packages, hasLength(1));
    expect(packages.single.identifier, 'pro_monthly');
    expect(packages.single.title, 'Pro Monthly');
    expect(packages.single.description, 'Monthly plan');
    expect(packages.single.priceLabel, r'$9.99');
    expect(packages.single.billingPeriod, 'month');
  });

  test(
    'getAvailablePackages returns empty when no offering is active',
    () async {
    final repository = RevenueCatSubscriptionRepository(
      getOfferings: () async => const Offerings({}),
    );

    expect(await repository.getAvailablePackages(), isEmpty);
    },
  );

  test('getSubscription maps an active entitlement', () async {
    final repository = RevenueCatSubscriptionRepository(
      getCustomerInfo: () async => _customerInfo(
        activeEntitlement: _entitlement(
          identifier: 'pro',
          isActive: true,
          productId: 'pro_monthly',
          expirationDate: '2026-04-11T00:00:00.000Z',
        ),
      ),
    );

    final subscription = await repository.getSubscription();

    expect(subscription.status, SubscriptionStatus.active);
    expect(subscription.entitlementId, 'pro');
    expect(subscription.productId, 'pro_monthly');
    expect(
      subscription.expiresAt,
      DateTime.parse(
        '2026-04-11T00:00:00.000Z',
      ),
    );
    expect(
      subscription.managementUrl,
      Uri.parse('https://example.com/manage'),
    );
  });

  test(
    'purchasePackage buys the matching package and maps the result',
    () async {
    PurchaseParams? capturedParams;
    final repository = RevenueCatSubscriptionRepository(
      getOfferings: () async => Offerings(
        {'default': _offering(packages: [_package(id: 'pro_yearly')])},
        current: _offering(packages: [_package(id: 'pro_yearly')]),
      ),
      purchasePackage: (purchaseParams) async {
        capturedParams = purchaseParams;
        return PurchaseResult(
          _customerInfo(
            activeEntitlement: _entitlement(
              identifier: 'pro',
              isActive: true,
              productId: 'pro_yearly',
            ),
          ),
          const StoreTransaction('txn-1', 'pro_yearly', '2026-03-11T12:00:00Z'),
        );
      },
    );

    final subscription = await repository.purchasePackage('pro_yearly');

    expect(capturedParams?.package?.identifier, 'pro_yearly');
    expect(subscription.productId, 'pro_yearly');
    expect(subscription.status, SubscriptionStatus.active);
    },
  );

  test('purchasePackage throws when the package is missing', () async {
    final repository = RevenueCatSubscriptionRepository(
      getOfferings: () async => Offerings(
        {'default': _offering(packages: [_package(id: 'pro_monthly')])},
        current: _offering(packages: [_package(id: 'pro_monthly')]),
      ),
    );

    await expectLater(
      repository.purchasePackage('missing'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Package missing was not found in the current offering.',
        ),
      ),
    );
  });

  test('restorePurchases maps an inactive entitlement', () async {
    final repository = RevenueCatSubscriptionRepository(
      entitlementId: 'legacy',
      restorePurchases: () async => _customerInfo(
        allEntitlement: _entitlement(
          identifier: 'legacy',
          isActive: false,
          productId: 'legacy_product',
        ),
      ),
    );

    final subscription = await repository.restorePurchases();

    expect(subscription.status, SubscriptionStatus.inactive);
    expect(subscription.entitlementId, 'legacy');
    expect(subscription.productId, 'legacy_product');
  });

  test(
    'watchSubscription relays updates and removes the listener on cancel',
    () async {
    CustomerInfoUpdateListener? registeredListener;
    CustomerInfoUpdateListener? removedListener;
    final repository = RevenueCatSubscriptionRepository(
      addCustomerInfoListener: (listener) {
        registeredListener = listener;
      },
      removeCustomerInfoListener: (listener) {
        removedListener = listener;
      },
    );

    final events = <SubscriptionModel>[];
    final subscription = repository.watchSubscription().listen(events.add);

    registeredListener!(
      _customerInfo(
        activeEntitlement: _entitlement(
          identifier: 'pro',
          isActive: true,
          productId: 'pro_monthly',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(events.single.status, SubscriptionStatus.active);
    expect(removedListener, same(registeredListener));
    },
  );
}

Package _package({required String id, String? billingPeriod}) {
  return Package(
    id,
    PackageType.custom,
    StoreProduct(
      id,
      'Monthly plan',
      id == 'pro_yearly' ? 'Pro Yearly' : 'Pro Monthly',
      9.99,
      r'$9.99',
      'USD',
      subscriptionPeriod: billingPeriod ?? 'P1M',
    ),
    const PresentedOfferingContext('default', null, null),
  );
}

Offering _offering({required List<Package> packages}) {
  return Offering('default', 'Default offering', const {}, packages);
}

CustomerInfo _customerInfo({
  EntitlementInfo? activeEntitlement,
  EntitlementInfo? allEntitlement,
}) {
  final active = <String, EntitlementInfo>{};
  final all = <String, EntitlementInfo>{};
  if (activeEntitlement != null) {
    active[activeEntitlement.identifier] = activeEntitlement;
    all[activeEntitlement.identifier] = activeEntitlement;
  }
  if (allEntitlement != null) {
    all[allEntitlement.identifier] = allEntitlement;
  }

  return CustomerInfo(
    EntitlementInfos(all, active),
    const {},
    const [],
    const [],
    const [],
    '2026-03-11T12:00:00.000Z',
    'user-123',
    const {},
    '2026-03-11T12:00:00.000Z',
    managementURL: 'https://example.com/manage',
  );
}

EntitlementInfo _entitlement({
  required String identifier,
  required bool isActive,
  required String productId,
  String? expirationDate,
}) {
  return EntitlementInfo(
    identifier,
    isActive,
    true,
    '2026-03-11T12:00:00.000Z',
    '2026-03-01T12:00:00.000Z',
    productId,
    false,
    expirationDate: expirationDate,
  );
}
