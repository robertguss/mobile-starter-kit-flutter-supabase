import 'dart:async';

import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

typedef CustomerInfoLoader = Future<CustomerInfo> Function();
typedef OfferingsLoader = Future<Offerings> Function();
typedef PackagePurchaser = Future<PurchaseResult> Function(
  PurchaseParams purchaseParams,
);
typedef PurchaseRestorer = Future<CustomerInfo> Function();
typedef CustomerInfoListenerRegistrar = void Function(
  CustomerInfoUpdateListener listener,
);
typedef CustomerInfoListenerRemover = void Function(
  CustomerInfoUpdateListener listener,
);

class RevenueCatSubscriptionRepository implements SubscriptionRepository {
  RevenueCatSubscriptionRepository({
    this.entitlementId = 'pro',
    CustomerInfoLoader? getCustomerInfo,
    OfferingsLoader? getOfferings,
    PackagePurchaser? purchasePackage,
    PurchaseRestorer? restorePurchases,
    CustomerInfoListenerRegistrar? addCustomerInfoListener,
    CustomerInfoListenerRemover? removeCustomerInfoListener,
  }) : _getCustomerInfo = getCustomerInfo ?? Purchases.getCustomerInfo,
       _getOfferings = getOfferings ?? Purchases.getOfferings,
       _purchasePackage = purchasePackage ?? Purchases.purchase,
       _restorePurchases = restorePurchases ?? Purchases.restorePurchases,
       _addCustomerInfoListener =
           addCustomerInfoListener ?? Purchases.addCustomerInfoUpdateListener,
       _removeCustomerInfoListener =
           removeCustomerInfoListener ??
           Purchases.removeCustomerInfoUpdateListener;

  final String entitlementId;
  final CustomerInfoLoader _getCustomerInfo;
  final OfferingsLoader _getOfferings;
  final PackagePurchaser _purchasePackage;
  final PurchaseRestorer _restorePurchases;
  final CustomerInfoListenerRegistrar _addCustomerInfoListener;
  final CustomerInfoListenerRemover _removeCustomerInfoListener;

  @override
  Future<List<SubscriptionPackageModel>> getAvailablePackages() async {
    final offering = (await _getOfferings()).current;
    if (offering == null) {
      return const [];
    }

    return offering.availablePackages.map(_mapPackage).toList(growable: false);
  }

  @override
  Future<SubscriptionModel> getSubscription() async {
    return _mapCustomerInfo(await _getCustomerInfo());
  }

  @override
  Future<SubscriptionModel> purchasePackage(String packageId) async {
    final package = await _findPackage(packageId);
    final result = await _purchasePackage(PurchaseParams.package(package));
    return _mapCustomerInfo(result.customerInfo);
  }

  @override
  Future<SubscriptionModel> restorePurchases() async {
    return _mapCustomerInfo(await _restorePurchases());
  }

  @override
  Stream<SubscriptionModel> watchSubscription() {
    late final StreamController<SubscriptionModel> controller;
    late final CustomerInfoUpdateListener listener;

    controller = StreamController<SubscriptionModel>.broadcast(
      onListen: () {
        listener = (customerInfo) {
          controller.add(_mapCustomerInfo(customerInfo));
        };
        _addCustomerInfoListener(listener);
      },
      onCancel: () {
        _removeCustomerInfoListener(listener);
      },
    );

    return controller.stream;
  }

  Future<Package> _findPackage(String packageId) async {
    final offering = (await _getOfferings()).current;
    if (offering == null) {
      throw StateError('No active RevenueCat offering is configured.');
    }

    for (final package in offering.availablePackages) {
      if (package.identifier == packageId) {
        return package;
      }
    }

    throw StateError(
      'Package $packageId was not found in the current offering.',
    );
  }

  SubscriptionPackageModel _mapPackage(Package package) {
    return SubscriptionPackageModel(
      identifier: package.identifier,
      title: package.storeProduct.title,
      description: package.storeProduct.description,
      priceLabel: package.storeProduct.priceString,
      billingPeriod: _billingPeriodLabel(package),
    );
  }

  SubscriptionModel _mapCustomerInfo(CustomerInfo customerInfo) {
    final entitlement =
        customerInfo.entitlements.active[entitlementId] ??
        customerInfo.entitlements.all[entitlementId] ??
        customerInfo.entitlements.active.values.firstOrNull;

    return SubscriptionModel(
      status:
          entitlement?.isActive == true
              ? SubscriptionStatus.active
              : SubscriptionStatus.inactive,
      entitlementId: entitlement?.identifier ?? entitlementId,
      productId: entitlement?.productIdentifier,
      expiresAt: _tryParseDateTime(entitlement?.expirationDate),
      managementUrl: _tryParseUri(customerInfo.managementURL),
    );
  }

  String _billingPeriodLabel(Package package) {
    final period = package.storeProduct.subscriptionPeriod;
    if (period == null) {
      return '';
    }

    return switch (period) {
      'P1W' => 'week',
      'P1M' => 'month',
      'P2M' => '2 months',
      'P3M' => '3 months',
      'P6M' => '6 months',
      'P1Y' => 'year',
      _ => period,
    };
  }

  DateTime? _tryParseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  Uri? _tryParseUri(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return Uri.tryParse(value);
  }
}

extension on Iterable<EntitlementInfo> {
  EntitlementInfo? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }
}
