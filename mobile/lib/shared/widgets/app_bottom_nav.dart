import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/language_switcher.dart';
import '../../core/theme/brand_palette.dart';
import '../../core/theme/theme_switcher.dart';
import '../../core/router/route_names.dart';

class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}

/// Role-aware bottom navigation with a polished More menu.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.userRole,
  });

  final String userRole;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;    
    final role = userRole.toLowerCase();
    final t = context.t;
    final p = BrandTokens.current;

    final primary = <AppNavItem>[];
    final overflow = <AppNavItem>[];

    switch (role) {
      case 'super_admin':
        primary.addAll([
          AppNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: t.dashboard,
            route: RouteNames.dashboard,
          ),
          AppNavItem(
            icon: Icons.point_of_sale_outlined,
            activeIcon: Icons.point_of_sale_rounded,
            label: t.pos,
            route: RouteNames.pos,
          ),
          AppNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: t.inventory,
            route: RouteNames.inventory,
          ),
          AppNavItem(
            icon: Icons.assessment_outlined,
            activeIcon: Icons.assessment_rounded,
            label: t.reports,
            route: RouteNames.reports,
          ),
        ]);
        overflow.addAll([
          AppNavItem(
            icon: Icons.store_outlined,
            activeIcon: Icons.store_rounded,
            label: t.shops,
            route: RouteNames.shops,
          ),
          AppNavItem(
            icon: Icons.people_outlined,
            activeIcon: Icons.people_rounded,
            label: t.users,
            route: RouteNames.users,
          ),
        ]);
        break;

      case 'owner':
      case 'store owner':
      case 'shop owner':
      case 'business owner':
      case 'school_manager':
      case 'school manager':
        primary.addAll([
          AppNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: t.dashboard,
            route: RouteNames.dashboard,
          ),
          AppNavItem(
            icon: Icons.point_of_sale_outlined,
            activeIcon: Icons.point_of_sale_rounded,
            label: t.pos,
            route: RouteNames.pos,
          ),
          AppNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: t.inventory,
            route: RouteNames.inventory,
          ),
          AppNavItem(
            icon: Icons.assessment_outlined,
            activeIcon: Icons.assessment_rounded,
            label: t.reports,
            route: RouteNames.reports,
          ),
        ]);
        overflow.addAll([
          AppNavItem(
            icon: Icons.local_shipping_outlined,
            activeIcon: Icons.local_shipping_rounded,
            label: t.purchases,
            route: RouteNames.purchases,
          ),
          AppNavItem(
            icon: Icons.people_outline_rounded,
            activeIcon: Icons.people_rounded,
            label: t.customers,
            route: RouteNames.customers,
          ),
          AppNavItem(
            icon: Icons.badge_outlined,
            activeIcon: Icons.badge_rounded,
            label: t.staff,
            route: RouteNames.staff,
          ),
          AppNavItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: t.transactions,
            route: RouteNames.transactions,
          ),
          AppNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: t.settings,
            route: RouteNames.settings,
          ),
        ]);
        break;

      case 'cashier':
        primary.addAll([
          AppNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: t.dashboard,
            route: RouteNames.dashboard,
          ),
          AppNavItem(
            icon: Icons.point_of_sale_outlined,
            activeIcon: Icons.point_of_sale_rounded,
            label: t.pos,
            route: RouteNames.pos,
          ),
          AppNavItem(
            icon: Icons.assessment_outlined,
            activeIcon: Icons.assessment_rounded,
            label: t.reports,
            route: RouteNames.reports,
          ),
        ]);
        break;

      default:
        primary.add(
          AppNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: t.dashboard,
            route: RouteNames.dashboard,
          ),
        );
    }

    final showMore = overflow.isNotEmpty;
    final overflowActive =
        overflow.any((item) => location.startsWith(item.route));

    int selected = overflowActive ? primary.length : 0;
    for (var i = 0; i < primary.length; i++) {
      if (location.startsWith(primary[i].route)) {
        selected = i;
        break;
      }
    }

    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: p.white,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: p.white,
          border: Border(top: BorderSide(color: p.border)),
          boxShadow: [
            BoxShadow(
              color: p.primary.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(8, 8, 8, bottom > 0 ? bottom : 10),
        child: Row(
          children: [
            for (var i = 0; i < primary.length; i++)
              Expanded(
                child: _NavTab(
                  item: primary[i],
                  selected: selected == i,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go(primary[i].route);
                  },
                ),
              ),
            if (showMore)
              Expanded(
                child: _NavTab(
                  item: AppNavItem(
                    icon: Icons.apps_outlined,
                    activeIcon: Icons.apps_rounded,
                    label: t.more,
                    route: '',
                  ),
                  selected: overflowActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    AppMoreMenu.show(
                      context,
                      items: overflow,
                      activeRoute: location,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = BrandTokens.current;
    final color = selected ? p.primary : p.inkMid;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: selected ? 52 : 40,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? p.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: selected ? -0.1 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Professional “More” menu (sidebar-style sheet).
class AppMoreMenu {
  static Future<void> show(
    BuildContext context, {
    required List<AppNavItem> items,
    required String activeRoute,
  }) {
    final p = BrandTokens.current;
    final t = context.t;

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxH = MediaQuery.sizeOf(sheetContext).height * 0.78;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: p.white,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              elevation: 8,
              shadowColor: p.primary.withValues(alpha: 0.18),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: p.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: p.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.grid_view_rounded,
                                  color: p.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.moreMenuTitle,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: p.ink,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Text(
                                    t.moreMenuSubtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.inkMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: Icon(Icons.close_rounded,
                                  color: p.inkMid, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t.quickAccess,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.inkMid,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.35,
                          ),
                          itemBuilder: (_, i) {
                            final item = items[i];
                            final active =
                                activeRoute.startsWith(item.route);
                            return _MoreTile(
                              item: item,
                              active: active,
                              onTap: () {
                                Navigator.pop(sheetContext);
                                context.go(item.route);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          t.preferences,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.inkMid,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: p.bg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.border),
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: const Column(
                            children: [
                              LanguageSwitcherTile(dense: true),
                              Divider(height: 12),
                              ThemeSwitcherTile(dense: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AppNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = BrandTokens.current;
    return Material(
      color: active ? p.primary.withValues(alpha: 0.1) : p.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? p.primary.withValues(alpha: 0.35) : p.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? p.primary : p.white,
                  borderRadius: BorderRadius.circular(10),
                  border: active ? null : Border.all(color: p.border),
                ),
                child: Icon(
                  active ? item.activeIcon : item.icon,
                  size: 18,
                  color: active ? p.white : p.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: p.inkMid.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
