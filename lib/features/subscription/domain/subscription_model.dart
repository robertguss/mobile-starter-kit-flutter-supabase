class SubscriptionModel {
  const SubscriptionModel({
    required this.status,
    required this.entitlementId,
    this.productId,
    this.expiresAt,
    this.managementUrl,
  });

  final SubscriptionStatus status;
  final String entitlementId;
  final String? productId;
  final DateTime? expiresAt;
  final Uri? managementUrl;

  bool get isActive => status == SubscriptionStatus.active;

  SubscriptionModel copyWith({
    SubscriptionStatus? status,
    String? entitlementId,
    String? productId,
    DateTime? expiresAt,
    Uri? managementUrl,
  }) {
    return SubscriptionModel(
      status: status ?? this.status,
      entitlementId: entitlementId ?? this.entitlementId,
      productId: productId ?? this.productId,
      expiresAt: expiresAt ?? this.expiresAt,
      managementUrl: managementUrl ?? this.managementUrl,
    );
  }
}

enum SubscriptionStatus { active, inactive }

class SubscriptionPackageModel {
  const SubscriptionPackageModel({
    required this.identifier,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.billingPeriod,
  });

  final String identifier;
  final String title;
  final String description;
  final String priceLabel;
  final String billingPeriod;
}
