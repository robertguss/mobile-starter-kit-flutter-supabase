import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/login_screen.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:flutter_supabase_starter/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app launches to the login screen', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: const ProviderScope(child: MyApp()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  });
}
