import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/core/widgets/async_value_widget.dart';
import 'package:flutter_supabase_starter/features/subscription/presentation/subscription_controller.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  static const routePath = '/paywall';
  static const screenKey = ValueKey<String>('paywall-screen');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionControllerProvider);

    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.t.subscription.title)),
      body: AsyncValueWidget(
        value: subscriptionAsync,
        onRetry: () => ref.invalidate(subscriptionControllerProvider),
        data: (state) {
          final subscription = state.subscription;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                subscription.isActive
                    ? context.t.subscription.active
                    : context.t.subscription.inactive,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (subscription.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${context.t.subscription.expiresAtLabel} '
                  '${subscription.expiresAt!.toIso8601String()}',
                ),
              ],
              const SizedBox(height: 24),
              Text(
                context.t.subscription.description,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (state.packages.isEmpty)
                Text(context.t.subscription.noPackages)
              else
                for (final package in state.packages) ...[
                  Card(
                    child: ListTile(
                      title: Text(package.title),
                      subtitle: Text(
                        '${package.description}\n'
                        '${package.priceLabel}'
                        '${package.billingPeriod.isEmpty
                            ? ''
                            : ' / ${package.billingPeriod}'}',
                      ),
                      trailing: FilledButton(
                        onPressed:
                            () => ref
                                .read(subscriptionControllerProvider.notifier)
                                .purchasePackage(package.identifier),
                        child: Text(context.t.subscription.subscribe),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              OutlinedButton(
                onPressed:
                    () => ref
                        .read(subscriptionControllerProvider.notifier)
                        .restorePurchases(),
                child: Text(context.t.subscription.restorePurchases),
              ),
            ],
          );
        },
      ),
    );
  }
}
