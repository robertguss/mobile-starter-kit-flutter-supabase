import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/providers/connectivity_provider.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityStatusProvider);

    return connectivity.when(
      data: (status) => Text(
        switch (status) {
          ConnectivityStatus.online => context.t.notes.onlineStatus,
          ConnectivityStatus.offline => context.t.notes.offlineStatus,
        },
      ),
      error: (error, stackTrace) => Text(context.t.notes.offlineStatus),
      loading: () => Text(context.t.notes.syncingStatus),
    );
  }
}
