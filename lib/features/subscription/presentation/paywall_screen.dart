import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  static const routePath = '/paywall';
  static const screenKey = ValueKey<String>('paywall-screen');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.t.subscription.title)),
      body: Center(child: Text(context.t.subscription.description)),
    );
  }
}
