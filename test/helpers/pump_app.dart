import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Widget? home,
  GoRouter? router,
  List<dynamic> overrides = const [],
}) async {
  final container = ProviderContainer(overrides: overrides.cast());

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig:
              router ??
              GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) => home ?? const SizedBox(),
                  ),
                ],
              ),
        ),
      ),
    ),
  );
  await tester.pump();

  return container;
}
