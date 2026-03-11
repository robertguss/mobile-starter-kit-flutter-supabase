import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/providers/connectivity_provider.dart';
import 'package:flutter_supabase_starter/features/notes/domain/note_model.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/widgets/note_card.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/widgets/sync_status_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  final sampleNote = NoteModel(
    id: 'note-1',
    userId: 'user-1',
    title: 'Weekly planning',
    body: 'Outline the next release milestones and offline sync checks.',
    createdAt: DateTime.utc(2026, 3, 11, 10),
    updatedAt: DateTime.utc(2026, 3, 11, 14, 30),
  );

  testWidgets('NoteCard matches golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const boundaryKey = ValueKey<String>('note-card-boundary');

    final container = await pumpApp(
      tester,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 320,
              child: NoteCard(note: sampleNote),
            ),
          ),
        ),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('../goldens/note_card.png'),
    );
  });

  testWidgets('SyncStatusIndicator matches golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const boundaryKey = ValueKey<String>('sync-status-boundary');

    final container = await pumpApp(
      tester,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  _IndicatorPreview(
                    label: 'Online',
                    stream: Stream.value(ConnectivityStatus.online),
                  ),
                  _IndicatorPreview(
                    label: 'Offline',
                    stream: Stream.value(ConnectivityStatus.offline),
                  ),
                  const _IndicatorPreview(
                    label: 'Loading',
                    stream: Stream.empty(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('../goldens/sync_status_indicator.png'),
    );
  });
}

class _IndicatorPreview extends StatelessWidget {
  const _IndicatorPreview({
    required this.label,
    required this.stream,
  });

  final String label;
  final Stream<ConnectivityStatus> stream;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        connectivityStatusProvider.overrideWith((ref) => stream),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SyncStatusIndicator(),
        ],
      ),
    );
  }
}
