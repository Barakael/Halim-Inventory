import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/products/presentation/pages/products_list_page.dart';
import '../../features/purchases/presentation/pages/purchases_hub_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/sales/presentation/pages/create_sale_page.dart';
import '../../features/sales/presentation/pages/sale_detail_page.dart';
import '../../features/sales/presentation/pages/sales_list_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/owner_settings_page.dart' as owner_settings;
import '../../features/shops/presentation/pages/shops_page.dart';
import '../../features/staff/presentation/pages/staff_page.dart';
import '../../features/customers/presentation/pages/customers_list_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../l10n/app_strings.dart';
import '../storage/secure_storage.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import 'route_names.dart';

class AppRouter {
  final SecureStorage secureStorage;

  AppRouter({required this.secureStorage});

  late final GoRouter router = GoRouter(
    initialLocation: RouteNames.login,
    redirect: _authGuard,
    routes: [
      GoRoute(
        path: RouteNames.home,
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (_, __) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path: RouteNames.pos,
            builder: (_, __) => const POSPage(),
          ),
          GoRoute(
            path: RouteNames.inventory,
            builder: (_, __) => const ProductsListPage(),
          ),
          GoRoute(
            path: RouteNames.purchases,
            builder: (_, __) => const PurchasesHubPage(),
          ),
          GoRoute(
            path: RouteNames.reports,
            builder: (_, __) => const ReportsPage(),
          ),
          GoRoute(
            path: RouteNames.users,
            builder: (_, __) => const UsersPage(),
          ),
          GoRoute(
            path: RouteNames.shops,
            builder: (_, __) => const ShopsPage(),
          ),
          GoRoute(
            path: RouteNames.staff,
            builder: (_, __) => const StaffPage(),
          ),
          GoRoute(
            path: RouteNames.customers,
            builder: (_, __) => const CustomersHubPage(),
          ),
          GoRoute(
            path: RouteNames.transactions,
            builder: (_, __) => const TransactionsPage(),
          ),
          GoRoute(
            path: RouteNames.settings,
            builder: (context, state) {
              return BlocBuilder<AuthBloc, AuthState>(
                builder: (context, authState) {
                  if (authState is AuthAuthenticated) {
                    final role = authState.user.roleName.toLowerCase().trim();
                    final isOwner = role == 'owner' ||
                        role == 'business owner' ||
                        role == 'store owner' ||
                        role == 'shop owner' ||
                        role == 'school_manager' ||
                        role == 'school manager' ||
                        role.contains('owner');
                    if (isOwner) {
                      return const owner_settings.OwnerSettingsPage();
                    }
                  }
                  return const SettingsPage();
                },
              );
            },
          ),
          // Order matters: `/sales/create` before `/sales/:id`.
          GoRoute(
            path: RouteNames.createSale,
            builder: (_, __) => const CreateSalePage(),
          ),
          GoRoute(
            path: '/sales/:id',
            builder: (context, state) => SaleDetailPage(
              saleId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: RouteNames.sales,
            builder: (_, __) => const SalesListPage(),
          ),
        ],
      ),
    ],
  );

  Future<String?> _authGuard(
    BuildContext context,
    GoRouterState state,
  ) async {
    final token = await secureStorage.getToken();
    final isLoggedIn = token != null;
    final loc = state.matchedLocation;

    // Legacy routes — login-only app
    if (loc == '/register' || loc.startsWith('/verify')) {
      return RouteNames.login;
    }

    if (loc == RouteNames.home) {
      if (isLoggedIn) return RouteNames.dashboard;
      return RouteNames.login;
    }

    if (loc == RouteNames.login) {
      if (isLoggedIn) return RouteNames.dashboard;
      return null;
    }

    if (!isLoggedIn) return RouteNames.login;

    UserModel? user;
    final raw = await secureStorage.getUser();
    if (raw != null) {
      try {
        user = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final role = user?.role?.name.toLowerCase() ?? '';

    if (loc.startsWith(RouteNames.users)) {
      if (role != 'super_admin') return RouteNames.dashboard;
    }
    if (loc.startsWith(RouteNames.shops)) {
      if (role != 'super_admin') return RouteNames.dashboard;
    }
    if (loc.startsWith(RouteNames.staff) ||
        loc.startsWith(RouteNames.customers) ||
        loc.startsWith(RouteNames.settings)) {
      if (role != 'owner' &&
          role != 'store owner' &&
          role != 'shop owner' &&
          role != 'business owner' &&
          role != 'school_manager' &&
          role != 'school manager') {
        return RouteNames.dashboard;
      }
    }
    if (loc.startsWith(RouteNames.inventory) ||
        loc.startsWith(RouteNames.purchases)) {
      if (role == 'cashier') return RouteNames.dashboard;
    }

    return null;
  }
}

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------

class DashboardShell extends StatelessWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthAuthenticated) {
          return Scaffold(
            body: child,
            bottomNavigationBar: AppBottomNav(
              userRole: authState.user.roleName,
            ),
          );
        }
        return Scaffold(body: child);
      },
    );
  }
}

