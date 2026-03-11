import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/auth_controller.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/otp_verify_screen.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const routePath = '/login';
  static const screenKey = ValueKey<String>('login-screen');

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.isLoading || !next.hasError) {
        return;
      }

      final message = switch (next.error) {
        InvalidEmailAuthException() => context.t.auth.invalidEmailError,
        _ => context.t.auth.sendOtpError,
      };

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      key: LoginScreen.screenKey,
      appBar: AppBar(title: Text(context.t.app.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t.auth.emailLabel),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  hintText: context.t.auth.emailHint,
                ),
                validator: (value) {
                  if (_isValidEmail(value ?? '')) {
                    return null;
                  }

                  return context.t.auth.invalidEmailError;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.t.auth.sendOtp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final email = _emailController.text.trim();
    final didSend = await ref.read(authControllerProvider.notifier).sendOtp(
          email,
        );
    if (!didSend || !mounted) {
      return;
    }

    context.go(OtpVerifyScreen.routeLocation(email));
  }

  bool _isValidEmail(String email) {
    const pattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    return RegExp(pattern).hasMatch(email.trim());
  }
}
