import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/providers/connectivity_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapConnectivityResults treats empty and none results as offline', () {
    expect(mapConnectivityResults(const []), ConnectivityStatus.offline);
    expect(
      mapConnectivityResults(const [ConnectivityResult.none]),
      ConnectivityStatus.offline,
    );
    expect(
      mapConnectivityResults(const [ConnectivityResult.wifi]),
      ConnectivityStatus.online,
    );
  });

  test('connectivityStatusProvider can be overridden in tests', () async {
    final container = ProviderContainer(
      overrides: [
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen<AsyncValue<ConnectivityStatus>>(
      connectivityStatusProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final value = await container.read(connectivityStatusProvider.future);

    expect(value, ConnectivityStatus.online);
  });
}
