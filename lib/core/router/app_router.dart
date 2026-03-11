import 'package:flutter/foundation.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/login_screen.dart';
import 'package:flutter_supabase_starter/features/auth/presentation/otp_verify_screen.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/note_detail_screen.dart';
import 'package:flutter_supabase_starter/features/notes/presentation/notes_list_screen.dart';
import 'package:flutter_supabase_starter/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter_supabase_starter/features/subscription/presentation/paywall_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

enum AuthRouteState { authenticated, unauthenticated }

class AuthRouteStateNotifier extends ChangeNotifier {
  AuthRouteStateNotifier(this._state);

  AuthRouteState _state;

  AuthRouteState get state => _state;

  void update(AuthRouteState nextState) {
    if (_state == nextState) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }
}

@riverpod
String routerInitialLocation(Ref ref) => NotesListScreen.routePath;

@Riverpod(keepAlive: true)
AuthRouteStateNotifier authRouteStateNotifier(Ref ref) {
  final notifier = AuthRouteStateNotifier(AuthRouteState.unauthenticated);
  ref.onDispose(notifier.dispose);
  return notifier;
}

@riverpod
GoRouter appRouter(Ref ref) {
  final authNotifier = ref.watch(authRouteStateProvider);
  final initialLocation = ref.watch(routerInitialLocationProvider);

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated =
          authNotifier.state == AuthRouteState.authenticated;
      final path = state.uri.path;
      final isAuthRoute = path == LoginScreen.routePath;
      final isOtpRoute = path == OtpVerifyScreen.routePath;
      final allowsUnauthenticated = isAuthRoute || isOtpRoute;

      if (!isAuthenticated && !allowsUnauthenticated) {
        return LoginScreen.routePath;
      }

      if (isAuthenticated && allowsUnauthenticated) {
        return NotesListScreen.routePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: LoginScreen.routePath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: OtpVerifyScreen.routePath,
        builder: (context, state) => OtpVerifyScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: NotesListScreen.routePath,
        builder: (context, state) => const NotesListScreen(),
      ),
      GoRoute(
        path: NoteDetailScreen.routePath,
        builder: (context, state) => NoteDetailScreen(
          noteId: state.pathParameters[NoteDetailScreen.noteIdParam]!,
        ),
      ),
      GoRoute(
        path: NotificationSettingsScreen.routePath,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: PaywallScreen.routePath,
        builder: (context, state) => const PaywallScreen(),
      ),
    ],
  );
}
