// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionManager)
final sessionManagerProvider = SessionManagerProvider._();

final class SessionManagerProvider
    extends $FunctionalProvider<SessionManager, SessionManager, SessionManager>
    with $Provider<SessionManager> {
  SessionManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionManagerHash();

  @$internal
  @override
  $ProviderElement<SessionManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionManager create(Ref ref) {
    return sessionManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionManager>(value),
    );
  }
}

String _$sessionManagerHash() => r'd069fa268bbe92147a861bab4e11333f02e6e01e';
