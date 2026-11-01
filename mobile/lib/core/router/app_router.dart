import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../storage/secure_storage.dart';
import 'route_names.dart';

/// Login, then the POS screen. Every other location follows that same rule.
class AppRouter {
  AppRouter({required this.secureStorage});

  final SecureStorage secureStorage;

  late final GoRouter router = GoRouter(
    initialLocation: RouteNames.login,
    redirect: _redirect,
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.pos,
        builder: (_, __) => const POSPage(),
      ),
    ],
  );

  Future<String?> _redirect(BuildContext context, GoRouterState state) async {
    final token = await secureStorage.getToken();
    final loggedIn = token != null;
    final loc = state.uri.path;

    if (!loggedIn) {
      return loc == RouteNames.login ? null : RouteNames.login;
    }
    if (loc != RouteNames.pos) return RouteNames.pos;
    return null;
  }
}
