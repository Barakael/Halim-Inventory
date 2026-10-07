import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/di/injection_container.dart';
import 'core/l10n/app_strings.dart';
import 'core/l10n/locale_cubit.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand_palette.dart';
import 'core/theme/theme_cubit.dart';
import 'features/analytics/presentation/bloc/analytics_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'core/router/route_names.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/products/presentation/bloc/products_bloc.dart';
import 'features/sales/presentation/bloc/sales_bloc.dart';
import 'features/staff/presentation/bloc/staff_bloc.dart';
import 'features/shops/presentation/bloc/shop_bloc.dart';
import 'features/transactions/presentation/bloc/transactions_bloc.dart';
import 'features/users/presentation/bloc/user_bloc.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with TickerProviderStateMixin {
  late final AppRouter _appRouter;
  bool _isInitialized = false;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ));

    _appRouter = AppRouter(secureStorage: sl<SecureStorage>());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _logoController.forward();
        
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _scaleController.forward();
          }
        }); 
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _fadeController.forward();
            setState(() {
              _isInitialized = true;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF0F0F1E),
                    Color(0xFF09090F),
                  ],
                ),
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _logoAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoAnimation.value,
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo (drop assets/images/logo/logo.png)
                                SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: Image.asset(
                                    'assets/images/logo/logo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.point_of_sale_rounded,
                                      size: 72,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Column(
                                    children: [
                                      const Text(
                                        'POS App',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppStrings.fromLocale(
                                                sl<LocaleCubit>().state)
                                            .appTagline,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),
                                // Loading indicator
                                AnimatedBuilder(
                                  animation: _fadeAnimation,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _fadeAnimation.value * 0.8,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                Colors.white.withValues(alpha: 0.2),
                                            width: 2,
                                          ),
                                        ),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<LocaleCubit>()),
        BlocProvider.value(value: sl<ThemeCubit>()),
        BlocProvider<AuthBloc>(
          create: (_) =>
              sl<AuthBloc>()..add(const AuthCheckStatusRequested()),
        ),
        BlocProvider<SalesBloc>(create: (_) => sl<SalesBloc>()),
        BlocProvider<ProductsBloc>(create: (_) => sl<ProductsBloc>()),
        BlocProvider<AnalyticsBloc>(create: (_) => sl<AnalyticsBloc>()),
        BlocProvider<StaffBloc>(create: (_) => sl<StaffBloc>()),
        BlocProvider<ShopBloc>(create: (_) => sl<ShopBloc>()),
        BlocProvider<TransactionsBloc>(
            create: (_) => sl<TransactionsBloc>()),
        BlocProvider<UserBloc>(create: (_) => sl<UserBloc>()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          final loc = _appRouter.router.state.matchedLocation;
          if (state is AuthAuthenticated) {
            if (loc == RouteNames.home || loc == RouteNames.login) {
              _appRouter.router.go(RouteNames.dashboard);
            }
          } else if (state is AuthUnauthenticated) {
            const publicRoutes = {RouteNames.login};
            if (!publicRoutes.contains(loc)) {
              _appRouter.router.go(RouteNames.login);
            }
          }
        },
        child: BlocBuilder<ThemeCubit, BrandPalette>(
          builder: (context, palette) {
            return BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                final t = AppStrings.fromLocale(locale);
                return MaterialApp.router(
                  title: t.appName,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightFor(palette),
                  darkTheme: AppTheme.dark,
                  themeMode: ThemeMode.light,
                  locale: locale,
                  supportedLocales: LocaleCubit.supported,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) {
                    return BrandPaletteScope(
                      palette: palette,
                      child: AppStringsScope(
                        strings: t,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
                  },
                  routerConfig: _appRouter.router,
                );
              },
            );
          },
        ),
      ),
    );
  }
}