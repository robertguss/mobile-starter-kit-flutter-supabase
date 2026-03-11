import 'package:flutter/foundation.dart';
import 'package:flutter_supabase_starter/core/observability/startup_metrics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('records phase, first frame, and total startup durations', () async {
    final stopwatch = _FakeStopwatch();
    final transaction = _RecordingSpan();
    final metrics = StartupMetrics(
      stopwatch: stopwatch,
      transaction: transaction,
    );

    stopwatch.elapse(const Duration(milliseconds: 125));
    await metrics.measurePhase('supabase_init', () {
      stopwatch.elapse(const Duration(milliseconds: 40));
    });
    stopwatch.elapse(const Duration(milliseconds: 35));
    metrics.recordFirstFrame();
    stopwatch.elapse(const Duration(milliseconds: 15));
    await metrics.finish();

    expect(
      transaction.measurements['app_start.phase.supabase_init'],
      const _Measurement(40, DurationSentryMeasurementUnit.milliSecond),
    );
    expect(
      transaction.measurements['app_start.first_frame'],
      const _Measurement(200, DurationSentryMeasurementUnit.milliSecond),
    );
    expect(
      transaction.measurements['app_start.total'],
      const _Measurement(215, DurationSentryMeasurementUnit.milliSecond),
    );
    expect(transaction.finishedWith, const SpanStatus.ok());
  });

  test('still records phase duration when the phase throws', () async {
    final stopwatch = _FakeStopwatch();
    final transaction = _RecordingSpan();
    final metrics = StartupMetrics(
      stopwatch: stopwatch,
      transaction: transaction,
    );

    expect(
      () => metrics.measurePhase<void>('powersync_open', () {
        stopwatch.elapse(const Duration(milliseconds: 55));
        throw StateError('boom');
      }),
      throwsStateError,
    );

    expect(
      transaction.measurements['app_start.phase.powersync_open'],
      const _Measurement(55, DurationSentryMeasurementUnit.milliSecond),
    );
  });
}

class _FakeStopwatch implements Stopwatch {
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;

  void elapse(Duration duration) {
    _elapsed += duration;
  }

  @override
  Duration get elapsed => _elapsed;

  @override
  int get elapsedMicroseconds => _elapsed.inMicroseconds;

  @override
  int get elapsedMilliseconds => _elapsed.inMilliseconds;

  @override
  int get elapsedTicks => _elapsed.inMicroseconds;

  @override
  int get frequency => Duration.microsecondsPerSecond;

  @override
  bool get isRunning => _isRunning;

  @override
  void reset() {
    _elapsed = Duration.zero;
  }

  @override
  void start() {
    _isRunning = true;
  }

  @override
  void stop() {
    _isRunning = false;
  }
}

class _RecordingSpan implements ISentrySpan {
  final measurements = <String, _Measurement>{};
  SpanStatus? finishedWith;

  @override
  dynamic throwable;

  @override
  SentrySpanContext get context =>
      throw UnimplementedError('Not needed for this test.');

  @override
  DateTime? get endTimestamp => null;

  @override
  bool get finished => finishedWith != null;

  @override
  String? origin;

  @override
  SentryTracesSamplingDecision? get samplingDecision => null;

  @override
  DateTime get startTimestamp => DateTime(2026);

  @override
  SpanStatus? status;

  @override
  Future<void> finish({
    SpanStatus? status,
    DateTime? endTimestamp,
    Hint? hint,
  }) async {
    finishedWith = status;
  }

  @override
  void removeData(String key) {}

  @override
  void removeTag(String key) {}

  @override
  void scheduleFinish() {}

  @override
  void setData(String key, dynamic value) {}

  @override
  void setMeasurement(
    String name,
    num value, {
    SentryMeasurementUnit? unit,
  }) {
    measurements[name] = _Measurement(value, unit);
  }

  @override
  void setTag(String key, String value) {}

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) {
    throw UnimplementedError('Not needed for this test.');
  }

  @override
  SentryBaggageHeader? toBaggageHeader() => null;

  @override
  SentryTraceHeader toSentryTrace() =>
      throw UnimplementedError('Not needed for this test.');

  @override
  SentryTraceContextHeader? traceContext() => null;
}

@immutable
class _Measurement {
  const _Measurement(this.value, this.unit);

  final num value;
  final SentryMeasurementUnit? unit;

  @override
  bool operator ==(Object other) {
    return other is _Measurement && other.value == value && other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(value, unit);
}
