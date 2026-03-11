import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/auth_controller.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_list_screen.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({
    required this.email,
    super.key,
  });

  static const routePath = '/otp-verify';
  static const screenKey = ValueKey<String>('otp-verify-screen');
  static const _cooldownSeconds = 30;

  static String routeLocation(String email) {
    return Uri(
      path: routePath,
      queryParameters: {'email': email},
    ).toString();
  }

  final String email;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  int _cooldownRemaining = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.isLoading || !next.hasError) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.t.auth.otpError)),
        );
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      key: OtpVerifyScreen.screenKey,
      appBar: AppBar(title: Text(context.t.auth.verifyOtp)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t.auth.otpLabel),
            const SizedBox(height: 12),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: context.t.auth.otpHint,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isLoading ? null : _verify,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t.auth.verifyOtp),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _cooldownRemaining > 0 ? null : _resendCode,
              child: Text(
                _cooldownRemaining > 0
                    ? context.t.auth.resendCooldown
                    : context.t.auth.resendOtp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verify() async {
    final didVerify = await ref.read(authControllerProvider.notifier).verifyOtp(
          email: widget.email,
          token: _otpController.text,
        );
    if (!didVerify || !mounted) {
      return;
    }

    context.go(NotesListScreen.routePath);
  }

  Future<void> _resendCode() async {
    final didSend = await ref.read(authControllerProvider.notifier).sendOtp(
          widget.email,
        );
    if (!didSend || !mounted) {
      return;
    }

    setState(() {
      _cooldownRemaining = OtpVerifyScreen._cooldownSeconds;
    });

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownRemaining <= 1) {
        timer.cancel();
        setState(() {
          _cooldownRemaining = 0;
        });
        return;
      }

      setState(() {
        _cooldownRemaining -= 1;
      });
    });
  }
}
