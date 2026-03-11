import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef ProviderExceptionCapture =
    Future<SentryId> Function(
      Object exception, {
      dynamic stackTrace,
      ScopeCallback? withScope,
    });

final class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver({
    ProviderExceptionCapture captureException = Sentry.captureException,
  }) : _captureException = captureException;

  final ProviderExceptionCapture _captureException;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    unawaited(
      _captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          unawaited(
            scope.setTag(
              'provider',
              context.provider.name ?? context.provider.toString(),
            ),
          );
        },
      ),
    );
  }
}
