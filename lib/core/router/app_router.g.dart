// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(routerInitialLocation)
final routerInitialLocationProvider = RouterInitialLocationProvider._();

final class RouterInitialLocationProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  RouterInitialLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routerInitialLocationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routerInitialLocationHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return routerInitialLocation(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$routerInitialLocationHash() =>
    r'3149d0e6d569958ca5af8642cd44d096197fb17b';

@ProviderFor(authRouteStateNotifier)
final authRouteStateProvider = AuthRouteStateNotifierProvider._();

final class AuthRouteStateNotifierProvider
    extends
        $FunctionalProvider<
          AuthRouteStateNotifier,
          AuthRouteStateNotifier,
          AuthRouteStateNotifier
        >
    with $Provider<AuthRouteStateNotifier> {
  AuthRouteStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRouteStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRouteStateNotifierHash();

  @$internal
  @override
  $ProviderElement<AuthRouteStateNotifier> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthRouteStateNotifier create(Ref ref) {
    return authRouteStateNotifier(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRouteStateNotifier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRouteStateNotifier>(value),
    );
  }
}

String _$authRouteStateNotifierHash() =>
    r'bb109d0d83c2fc1ed832d72c1ca7ed6cf7d05b4e';

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'e231a722784e86f2d4405a10df4c444d28f579d0';
