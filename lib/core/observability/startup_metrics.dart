import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

class StartupMetrics {
  StartupMetrics({
    required Stopwatch stopwatch,
    required ISentrySpan transaction,
  }) : _stopwatch = stopwatch,
       _transaction = transaction {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
  }

  factory StartupMetrics.start() {
    return StartupMetrics(
      stopwatch: Stopwatch(),
      transaction: Sentry.startTransaction(
        'app.startup',
        'app.start',
        bindToScope: false,
      ),
    );
  }

  final Stopwatch _stopwatch;
  final ISentrySpan _transaction;
  bool _didRecordFirstFrame = false;

  Future<T> measurePhase<T>(
    String phaseName,
    FutureOr<T> Function() action,
  ) async {
    final startedAt = _stopwatch.elapsedMicroseconds;

    try {
      return await action();
    } finally {
      _recordMeasurement(
        'app_start.phase.$phaseName',
        _stopwatch.elapsedMicroseconds - startedAt,
      );
    }
  }

  void recordFirstFrame() {
    if (_didRecordFirstFrame) {
      return;
    }

    _didRecordFirstFrame = true;
    _recordMeasurement('app_start.first_frame', _stopwatch.elapsedMicroseconds);
  }

  Future<void> finish({
    SpanStatus status = const SpanStatus.ok(),
  }) async {
    _recordMeasurement('app_start.total', _stopwatch.elapsedMicroseconds);
    await _transaction.finish(status: status);
  }

  void _recordMeasurement(String name, int elapsedMicroseconds) {
    _transaction.setMeasurement(
      name,
      elapsedMicroseconds / Duration.microsecondsPerMillisecond,
      unit: DurationSentryMeasurementUnit.milliSecond,
    );
  }
}
