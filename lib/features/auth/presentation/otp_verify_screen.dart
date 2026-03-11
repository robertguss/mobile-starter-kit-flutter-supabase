import 'package:flutter/material.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';

class OtpVerifyScreen extends StatelessWidget {
  const OtpVerifyScreen({super.key});

  static const routePath = '/otp-verify';
  static const screenKey = ValueKey<String>('otp-verify-screen');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.t.auth.verifyOtp)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.auth.otpLabel),
            const SizedBox(height: 12),
            const TextField(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {},
              child: Text(context.t.auth.verifyOtp),
            ),
          ],
        ),
      ),
    );
  }
}
