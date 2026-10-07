import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/staff_bloc.dart';
import '../bloc/staff_event.dart';
import '../bloc/staff_state.dart';
import '../../domain/entities/staff_entity.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';

class _T {
  static BrandPalette get _p => BrandTokens.current;
  static Color get bg => _p.bg;
  static Color get white => _p.white;
  static Color get primary => _p.primary;
  static Color get primaryLt => _p.primaryLt;
  static Color get accent => _p.accent;
  static Color get accentSoft => _p.accentSoft;
  static Color get danger => _p.danger;
  static Color get dangerSoft => _p.dangerSoft;
  static Color get warn => _p.warn;
  static Color get warnSoft => _p.warn.withValues(alpha: 0.12);
  static Color get ink => _p.ink;
  static Color get inkMid => _p.inkMid;
  static Color get inkLight => const Color(0xFFCBD5E1);
  static Color get border => _p.border;

  static TextStyle ts(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _p.ts(
        size,
        weight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static List<BoxShadow> get cardShadow => _p.cardShadow;
  static Color primaryOpacity(double o) => _p.primaryOpacity(o);
  static Color whiteOpacity(double o) => white.withValues(alpha: o);
}

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StaffBloc>().add(const StaffRequested());
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: _T.ts(13, weight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: error ? _T.danger : _T.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddStaffSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffFormSheet(
        onSave: (name, email, password, branchId) {
          context.read<StaffBloc>().add(StaffCreateRequested(
                name: name,
                email: email,
                password: password,
                branchId: branchId,
              ));
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showEditStaffSheet(StaffEntity staff) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffFormSheet(
        staff: staff,
        onSave: (name, email, password, branchId) {
          context.read<StaffBloc>().add(StaffUpdateRequested(
                id: staff.id,
                name: name,
                email: email,
                password: password,
                branchId: branchId,
              ));
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showDeleteConfirm(StaffEntity staff) {
    if (!mounted) return;
    final name = '${staff.firstName} ${staff.lastName}'.trim();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final t = ctx.t;
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.removeStaffMember,
                    style: _T.ts(17, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.removeStaffConfirm(name),
                    style: _T.ts(13, color: _T.inkMid, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        context
                            .read<StaffBloc>()
                            .add(StaffDeleteRequested(staff.id));
                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.person_remove_outlined, size: 18),
                      label: Text(
                        t.remove,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _T.danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _T.inkMid,
                        side: BorderSide(color: _T.border),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(t.cancel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<StaffEntity> _filterStaff(List<StaffEntity> staff) {
    if (_searchQuery.isEmpty) return staff;
    final q = _searchQuery.toLowerCase();
    return staff.where((s) {
      final fullName = '${s.firstName} ${s.lastName}'.toLowerCase();
      final email = s.email.toLowerCase();
      final phone = (s.phone).toLowerCase();
      final branch = (s.branchName ?? '').toLowerCase();
      return fullName.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          branch.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AppPageScaffold(
      title: t.staff,
      subtitle: t.manageYourTeam,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          tooltip: t.search,
          onPressed: () => setState(() {
            _isSearchVisible = !_isSearchVisible;
            if (!_isSearchVisible) {
              _searchQuery = '';
              _searchController.clear();
            }
          }),
          icon: Icon(
            _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
          ),
        ),
        IconButton(
          tooltip: t.addCashier,
          onPressed: _showAddStaffSheet,
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
        const SizedBox(width: 4),
      ],
      body: BlocConsumer<StaffBloc, StaffState>(
          listener: (context, state) {
            if (!mounted) return;
            if (state is StaffCreated) {
              _showToast(context.t.staffAdded);
              _animController
                ..reset()
                ..forward();
            } else if (state is StaffUpdated) {
              _showToast(context.t.staffUpdated);
            } else if (state is StaffDeleted) {
              _showToast(context.t.staffRemoved);
            } else if (state is StaffError) {
              _showToast(state.message, error: true);
            }
          },
          builder: (context, state) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (_isSearchVisible)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        autofocus: true,
                        style: _T.ts(14),
                        decoration: InputDecoration(
                          hintText: t.searchStaffHint,
                          hintStyle: _T.ts(13, color: _T.inkMid),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 20, color: _T.inkMid),
                          filled: true,
                          fillColor: _T.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _T.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _T.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: _T.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (state is StaffLoading)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: _T.primary,
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 14),
                          Text(t.loadingStaff,
                              style: _T.ts(13, color: _T.inkMid)),
                        ],
                      ),
                    ),
                  )
                else if (state is StaffError)
                  SliverFillRemaining(
                    child: _ErrorState(
                      message: state.message,
                      onRetry: () => context
                          .read<StaffBloc>()
                          .add(const StaffRequested()),
                    ),
                  )
                else if (state is StaffLoaded) ...[
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _StaffStats(staff: state.staff),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            t.teamMembers,
                            style: _T.ts(15, weight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: _T.primaryOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _filterStaff(state.staff).length.toString(),
                              style: _T.ts(
                                11,
                                weight: FontWeight.w600,
                                color: _T.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Builder(builder: (context) {
                    final filtered = _filterStaff(state.staff);

                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(
                          message: _searchQuery.isNotEmpty
                              ? t.noResultsFor(_searchQuery)
                              : t.noStaffYet,
                          onAdd: _showAddStaffSheet,
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= filtered.length) {
                            return const SizedBox.shrink();
                          }
                          final staff = filtered[index];
                          final isLast = index == filtered.length - 1;

                          return FadeTransition(
                            opacity: _fadeAnim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: _animController,
                                curve: Interval(
                                  (index * 0.05).clamp(0.0, 0.6),
                                  1.0,
                                  curve: Curves.easeOutCubic,
                                ),
                              )),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  isLast ? 24 : 8,
                                ),
                                child: _StaffCard(
                                  staff: staff,
                                  onEdit: () => _showEditStaffSheet(staff),
                                  onDelete: () => _showDeleteConfirm(staff),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    );
                  }),
                ] else
                  SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _T.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
    );
  }
}

class _StaffStats extends StatelessWidget {
  final List<StaffEntity> staff;
  const _StaffStats({required this.staff});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final branches = staff
        .map((s) => s.branchId)
        .whereType<int>()
        .toSet()
        .length;

    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: t.totalLabel,
            value: staff.length,
            color: _T.primary,
            bg: _T.primaryOpacity(0.1),
            icon: Icons.people_alt_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: t.cashiersLabel,
            value: staff.length,
            color: _T.warn,
            bg: _T.warnSoft,
            icon: Icons.point_of_sale_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            label: t.branchesLabel,
            value: branches,
            color: _T.accent,
            bg: _T.accentSoft,
            icon: Icons.storefront_rounded,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color bg;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: _T.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _T.ts(18, weight: FontWeight.w800, height: 1.0),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _T.ts(
                  10,
                  color: _T.inkMid,
                  weight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffEntity staff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffCard({
    required this.staff,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _roleColor {
    switch (staff.roleName?.toLowerCase()) {
      case 'owner':
        return _T.accent;
      case 'cashier':
        return _T.warn;
      default:
        return _T.primary;
    }
  }

  Color get _roleBg {
    switch (staff.roleName?.toLowerCase()) {
      case 'owner':
        return _T.accentSoft;
      case 'cashier':
        return _T.warnSoft;
      default:
        return _T.primaryOpacity(0.1);
    }
  }

  String get _initials {
    final first =
        staff.firstName.isNotEmpty ? staff.firstName[0].toUpperCase() : '?';
    final last =
        staff.lastName.isNotEmpty ? staff.lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final branch = staff.branchName?.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _roleBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                _initials,
                style: _T.ts(13, weight: FontWeight.w800, color: _roleColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${staff.firstName} ${staff.lastName}'.trim(),
                  style: _T.ts(14, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    staff.email,
                    if (branch != null && branch.isNotEmpty) branch,
                  ].join(' · '),
                  style: _T.ts(12, color: _T.inkMid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: _T.inkMid, size: 20),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(t.edit)),
              PopupMenuItem(value: 'delete', child: Text(t.remove)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _T.inkMid),
          const SizedBox(width: 5),
          Text(label, style: _T.ts(11, color: _T.inkMid, weight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final Color color;
  final Color bg;

  const _RoleBadge({
    required this.role,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final display =
        role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : role;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        display,
        style: _T.ts(11, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _CardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _CardBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: _T.ts(12, weight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  bool get _isEmptyResult {
    final m = message.toLowerCase();
    return m.contains('no staff') ||
        m.contains('not found') ||
        m.contains('empty');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _isEmptyResult
                    ? _T.primaryOpacity(0.08)
                    : _T.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isEmptyResult
                    ? Icons.people_outline_rounded
                    : Icons.wifi_off_rounded,
                size: 32,
                color: _isEmptyResult ? _T.primary : _T.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEmptyResult ? t.noStaffYet : t.unableToLoadStaff,
              style: _T.ts(16, weight: FontWeight.w700, color: _T.ink),
            ),
            const SizedBox(height: 6),
            Text(
              _isEmptyResult ? t.tapToAddStaff : t.checkConnectionRetry,
              style: _T.ts(13, color: _T.inkMid),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: _T.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      t.retry,
                      style: _T.ts(13, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onAdd;

  const _EmptyState({required this.message, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _T.bg,
                shape: BoxShape.circle,
                border: Border.all(color: _T.border, width: 2),
              ),
              child: Icon(Icons.people_outline_rounded,
                  size: 32, color: _T.inkLight),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: _T.ts(15, weight: FontWeight.w600, color: _T.inkMid),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              t.tapToAddStaff,
              style: _T.ts(12, color: _T.inkLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _T.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      t.addCashier,
                      style: _T.ts(13, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              style: _T.ts(14),
              decoration: InputDecoration(
                hintText: context.t.searchStaffHint,
                hintStyle: _T.ts(13, color: _T.inkMid),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: _T.inkMid),
                filled: true,
                fillColor: _T.white.withValues(alpha: 0.14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white70, width: 1.2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _T.whiteOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _T.whiteOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _StaffFormSheet extends StatefulWidget {
  final StaffEntity? staff;
  final void Function(
    String name,
    String email,
    String password,
    int branchId,
  ) onSave;

  const _StaffFormSheet({this.staff, required this.onSave});

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  int _selectedBranchId = 0;
  bool _obscure = true;
  bool _branchesLoading = true;
  bool _branchTouched = false;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    if (widget.staff != null) {
      final s = widget.staff!;
      _nameCtrl.text = '${s.firstName} ${s.lastName}'.trim();
      _emailCtrl.text = s.email;
      _selectedBranchId = s.branchId ?? 0;
    }
    _loadBranches();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() => _branchesLoading = true);
    try {
      final list = await sl<ApiClient>().get<List<dynamic>>(
        endpoint: ApiEndpoints.branches,
        parser: (json) {
          if (json is List) return json;
          if (json is Map<String, dynamic> && json['data'] is List) {
            return json['data'] as List<dynamic>;
          }
          return <dynamic>[];
        },
      );
      final branches = list.map((e) {
        final m = e as Map<String, dynamic>;
        return {
          'id': (m['id'] as num).toInt(),
          'name': m['name']?.toString() ?? 'Branch',
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _branchesLoading = false;
        if (_selectedBranchId == 0 && branches.isNotEmpty) {
          _selectedBranchId = branches.first['id'] as int;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _branches = [];
          _branchesLoading = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _selectedBranch {
    for (final b in _branches) {
      if (b['id'] == _selectedBranchId) return b;
    }
    return null;
  }

  Future<void> _openBranchPicker() async {
    if (_branchesLoading) return;
    if (_branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.addBranchInSettings),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _branchTouched = true);
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchPickerSheet(
        branches: _branches,
        selectedId: _selectedBranchId,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedBranchId = selected);
    }
  }

  void _submit() {
    setState(() => _branchTouched = true);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_selectedBranchId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.selectBranchFirst),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final isEdit = widget.staff != null;
    widget.onSave(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      isEdit ? '' : _passwordCtrl.text,
      _selectedBranchId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isEdit = widget.staff != null;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: _T.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_T.primary, _T.primaryLt],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            isEdit
                                ? Icons.edit_rounded
                                : Icons.person_add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? t.editCashier : t.addCashier,
                                style: _T.ts(
                                  16,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.cashierFormHint,
                                style: _T.ts(11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FormField(
                          controller: _nameCtrl,
                          label: t.fullName,
                          hint: 'Jane Doe',
                          icon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? t.requiredField
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _FormField(
                          controller: _emailCtrl,
                          label: t.emailAddress,
                          hint: 'cashier@shop.com',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return t.requiredField;
                            }
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _BranchPickerField(
                          label: t.branchLabel,
                          loading: _branchesLoading,
                          selectedName: _selectedBranch?['name'] as String?,
                          empty: !_branchesLoading && _branches.isEmpty,
                          error: _branchTouched && _selectedBranchId == 0,
                          onTap: _openBranchPicker,
                        ),
                        if (!_branchesLoading && _branches.isEmpty) ...[
                          const SizedBox(height: 10),
                          _NoBranchesBanner(
                            onOpenSettings: () {
                              Navigator.of(context).pop();
                              context.go(RouteNames.settings);
                            },
                          ),
                        ],
                        if (!isEdit) ...[
                          const SizedBox(height: 16),
                          _FormField(
                            controller: _passwordCtrl,
                            label: t.password,
                            hint: t.passwordMinHint,
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: _T.inkMid,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return t.requiredField;
                              if (v.length < 8) return t.passwordMinHint;
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _branchesLoading ? null : _submit,
                          icon: Icon(
                            isEdit
                                ? Icons.save_rounded
                                : Icons.person_add_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isEdit ? t.saveChanges : t.addCashier,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _T.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _T.primary.withValues(alpha: 0.4),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _T.inkMid,
                            side: BorderSide(color: _T.border),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(t.cancel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
        ),
      ),
    );
  }
}

class _NoBranchesBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _NoBranchesBanner({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _T.warnSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.warn.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _T.warn, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.addBranchInSettings,
              style: _T.ts(12, color: _T.ink, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: Text(
              t.settings,
              style: _T.ts(12, weight: FontWeight.w700, color: _T.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchPickerField extends StatelessWidget {
  final String label;
  final bool loading;
  final bool empty;
  final bool error;
  final String? selectedName;
  final VoidCallback onTap;

  const _BranchPickerField({
    required this.label,
    required this.loading,
    required this.empty,
    required this.error,
    required this.selectedName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final selected = selectedName != null && selectedName!.isNotEmpty;
    final borderColor = error
        ? _T.danger
        : selected
            ? _T.primary.withValues(alpha: 0.45)
            : _T.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _T.ts(13, weight: FontWeight.w600, color: _T.primary),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _T.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: selected || error ? 1.6 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? _T.primaryOpacity(0.1)
                          : _T.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _T.border),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 18,
                      color: selected ? _T.primary : _T.inkMid,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: loading
                        ? Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _T.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                t.loadingBranches,
                                style: _T.ts(13, color: _T.inkMid),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected
                                    ? selectedName!
                                    : empty
                                        ? t.noBranchesYet
                                        : t.selectBranch,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _T.ts(
                                  14,
                                  weight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected ? _T.ink : _T.inkMid,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selected
                                    ? t.assignedLocation
                                    : t.assignToBranch,
                                style: _T.ts(11, color: _T.inkMid),
                              ),
                            ],
                          ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _T.inkMid,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error) ...[
          const SizedBox(height: 6),
          Text(
            t.selectBranchFirst,
            style: _T.ts(11, color: _T.danger),
          ),
        ],
      ],
    );
  }
}

class _BranchPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> branches;
  final int selectedId;

  const _BranchPickerSheet({
    required this.branches,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.62,
      ),
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _T.inkLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _T.primaryOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.storefront_rounded,
                      color: _T.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.assignToBranch,
                    style: _T.ts(16, weight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: _T.inkMid),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: branches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final branch = branches[index];
                final id = branch['id'] as int;
                final name = branch['name'] as String;
                final selected = id == selectedId;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(id),
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? _T.primaryOpacity(0.08) : _T.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? _T.primary.withValues(alpha: 0.45)
                              : _T.border,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selected ? _T.primary : _T.white,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: selected ? Colors.white : _T.inkMid,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: _T.ts(
                                    14,
                                    weight: FontWeight.w700,
                                    color: _T.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t.assignedLocation,
                                  style: _T.ts(11, color: _T.inkMid),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: selected ? _T.accent : _T.inkLight,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _T.ts(13, weight: FontWeight.w600, color: _T.primary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          validator: validator,
          style: _T.ts(14, weight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _T.ts(13, color: _T.inkMid),
            prefixIcon: Icon(icon, size: 18, color: _T.inkMid),
            suffixIcon: suffix,
            filled: true,
            fillColor: _T.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _T.border, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _T.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _T.primary, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _T.danger, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _T.danger, width: 1.5),
            ),
            errorStyle: _T.ts(11, color: _T.danger),
          ),
        ),
      ],
    );
  }
}
