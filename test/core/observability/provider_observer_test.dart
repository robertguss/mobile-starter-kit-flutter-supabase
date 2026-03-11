import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/observability/provider_observer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('providerDidFail reports the provider name to Sentry', () async {
    Object? capturedError;
    StackTrace? capturedStackTrace;
    Scope? scope;
    final provider = Provider<int>(
      name: 'failingProvider',
      (ref) => throw StateError('boom'),
    );
    final observer = AppProviderObserver(
      captureException: (
        exception, {
        stackTrace,
        withScope,
      }) async {
        capturedError = exception;
        capturedStackTrace = stackTrace as StackTrace?;
        scope = Scope(SentryOptions(dsn: 'https://example@sentry.io/1'));
        await withScope?.call(scope!);
        return const SentryId.empty();
      },
    );
    final container = ProviderContainer(observers: [observer]);
    addTearDown(container.dispose);

    expect(
      () => container.read(provider),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('Bad state: boom'),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(capturedError, isA<StateError>());
    expect(capturedStackTrace, isNotNull);
    expect(scope?.tags['provider'], 'failingProvider');
  });
}
