import 'dart:async';

import 'package:flutter_supabase_starter/core/providers/connectivity_provider.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/widgets/sync_status_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  testWidgets('shows online label when connectivity is online', (tester) async {
    final container = await pumpApp(
      tester,
      home: const SyncStatusIndicator(),
      overrides: [
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpAndSettle();

    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('shows offline label when connectivity is offline', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      home: const SyncStatusIndicator(),
      overrides: [
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.offline),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('shows syncing label while status is still loading', (
    tester,
  ) async {
    final controller = StreamController<ConnectivityStatus>.broadcast();
    addTearDown(controller.close);

    final container = await pumpApp(
      tester,
      home: const SyncStatusIndicator(),
      overrides: [
        connectivityStatusProvider.overrideWith((ref) => controller.stream),
      ],
    );
    addTearDown(container.dispose);

    await tester.pump();

    expect(find.text('Syncing...'), findsOneWidget);
  });
}
