import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isActive reflects the current subscription status', () {
    const active = SubscriptionModel(
      status: SubscriptionStatus.active,
      entitlementId: 'pro',
    );
    const inactive = SubscriptionModel(
      status: SubscriptionStatus.inactive,
      entitlementId: 'pro',
    );

    expect(active.isActive, isTrue);
    expect(inactive.isActive, isFalse);
  });

  test('copyWith keeps existing values and applies overrides', () {
    final model = SubscriptionModel(
      status: SubscriptionStatus.inactive,
      entitlementId: 'pro',
      productId: 'starter',
      expiresAt: DateTime.utc(2026, 3, 11),
    );

    final updated = model.copyWith(status: SubscriptionStatus.active);

    expect(updated.status, SubscriptionStatus.active);
    expect(updated.entitlementId, 'pro');
    expect(updated.productId, 'starter');
    expect(updated.expiresAt, DateTime.utc(2026, 3, 11));
  });
}
