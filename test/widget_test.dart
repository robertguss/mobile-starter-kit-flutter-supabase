import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/login_screen.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_model.dart';
import 'package:flutter_supabase_starter/features/subscription/domain/subscription_repository.dart';
import 'package:flutter_supabase_starter/i18n/strings.g.dart';
import 'package:flutter_supabase_starter/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'features/subscription/domain/mock_subscription_repository.dart';

void main() {
  late MockSubscriptionRepository subscriptionRepository;

  setUp(() {
    subscriptionRepository = MockSubscriptionRepository();
    when(
      subscriptionRepository.watchSubscription,
    ).thenAnswer((_) => const Stream.empty());
    when(
      subscriptionRepository.getSubscription,
    ).thenAnswer(
      (_) async => const SubscriptionModel(
        status: SubscriptionStatus.inactive,
        entitlementId: 'pro',
      ),
    );
    when(
      subscriptionRepository.getAvailablePackages,
    ).thenAnswer((_) async => const []);
  });

  testWidgets('app launches to the login screen', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(
              subscriptionRepository,
            ),
          ],
          child: const MyApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(LoginScreen.screenKey), findsOneWidget);
  });
}
