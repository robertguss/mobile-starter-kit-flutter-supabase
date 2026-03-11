import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

enum ConnectivityStatus { online, offline }

ConnectivityStatus _mapConnectivity(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.none) || results.isEmpty) {
    return ConnectivityStatus.offline;
  }

  return ConnectivityStatus.online;
}

@riverpod
Stream<ConnectivityStatus> connectivityStatus(Ref ref) async* {
  final connectivity = Connectivity();

  yield _mapConnectivity(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_mapConnectivity).distinct();
}
