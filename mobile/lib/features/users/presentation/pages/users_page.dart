import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/user_bloc.dart';
import '../bloc/user_event.dart';
import '../bloc/user_state.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all';
  bool _isSearchVisible = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Palette ──────────────────────────────────────────────────────────────
  static const _void       = Color(0xFF09090F);
  static const _surface    = Color(0xFF111118);
  static const _panel      = Color(0xFF16161F);
  static const _card       = Color(0xFF1C1C28);
  static const _border     = Color(0x18FFFFFF);
  static const _ink        = Color(0xFFF0F0FF);
  static const _inkMid     = Color(0xFF8B8BA8);
  static const _inkDim     = Color(0xFF4A4A62);
  static const _gold       = Color(0xFFF5C842);
  static const _goldSoft   = Color(0x20F5C842);
  static const _teal       = Color(0xFF00D9A3);
  static const _tealSoft   = Color(0x1A00D9A3);
  static const _coral      = Color(0xFFFF5F6D);
  static const _coralSoft  = Color(0x1AFF5F6D);
  static const _indigo     = Color(0xFF7B68EE);
  static const _indigoSoft = Color(0x1F7B68EE);
  static const _amber      = Color(0xFFFF9F43);
  static const _amberSoft  = Color(0x1FFF9F43);

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
    context.read<UserBloc>().add(const UsersFetchRequested());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  List<dynamic> _getFiltered(List<dynamic> users) {
    return users.where((u) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          (u.name as String).toLowerCase().contains(q) ||
          (u.email as String).toLowerCase().contains(q);
      final matchFilter = _filter == 'all' || u.role == _filter;
      return matchSearch && matchFilter;
    }).toList();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showToast(String message, {bool error = false}) {
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
                child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: error ? _coral : _teal,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showUserSheet(dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(
        user: user,
        onSave: (data) {
          if (user != null) {
            context.read<UserBloc>().add(UserUpdateRequested(user.id, data));
          } else {
            context.read<UserBloc>().add(UserCreateRequested(data));
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showDeleteConfirm(String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete User',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
          style: const TextStyle(
              fontSize: 13, color: _inkMid, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: _inkMid)),
          ),
          FilledButton(
            onPressed: () {
              context.read<UserBloc>().add(UserDeleteRequested(id));
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _void,
      ),
      child: Scaffold(
        backgroundColor: _void,
        body: BlocConsumer<UserBloc, UserState>(
          listener: (context, state) {
            if (state is UserActionSuccess) {
              _showToast(state.message);
              context.read<UserBloc>().add(const UsersFetchRequested());
              _animController.reset();
              _animController.forward();
            } else if (state is UserError) {
              _showToast(state.message, error: true);
            } else if (state is UsersLoaded) {
              if (!_animController.isCompleted) _animController.forward();
            }
          },
          builder: (context, state) {
            final users =
                state is UsersLoaded ? state.users : <dynamic>[];
            final filtered = _getFiltered(users);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── App Bar ────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: _surface,
                  foregroundColor: _ink,
                  elevation: 0,
                  pinned: true,
                  expandedHeight: 110,
                  surfaceTintColor: Colors.transparent,
                  systemOverlayStyle: SystemUiOverlayStyle.light,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    title: _isSearchVisible
                        ? _SearchBar(
                            controller: _searchController,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                            onClose: () => setState(() {
                              _isSearchVisible = false;
                              _searchQuery = '';
                              _searchController.clear();
                            }),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Users',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state is UsersLoaded
                                    ? '${state.users.length} users total'
                                    : 'Manage accounts',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _inkDim,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                    background: Container(
                      decoration: const BoxDecoration(
                        color: _surface,
                        border: Border(
                            bottom: BorderSide(color: _border)),
                      ),
                    ),
                  ),
                  actions: [
                    if (!_isSearchVisible) ...[
                      _IconBtn(
                        icon: Icons.search_rounded,
                        onTap: () =>
                            setState(() => _isSearchVisible = true),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () => _showUserSheet(null),
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 16, color: _void),
                                SizedBox(width: 5),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _void,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Role Filter Tabs ───────────────────────────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _RoleTabDelegate(
                    users: users,
                    selected: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                ),

                // ── Content ────────────────────────────────────────
                if (state is UsersLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: _gold, strokeWidth: 2),
                    ),
                  )
                else if (state is UserError)
                  SliverFillRemaining(
                    child: _ErrorState(
                      message: state.message,
                      onRetry: () => context
                          .read<UserBloc>()
                          .add(const UsersFetchRequested()),
                    ),
                  )
                else if (users.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      message: 'No users yet',
                      onAdd: () => _showUserSheet(null),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No results for "$_searchQuery"'
                            : 'No users in this role',
                        style: const TextStyle(
                            fontSize: 13, color: _inkDim),
                      ),
                    ),
                  )
                else ...[
                  // Stats row
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            16, 20, 16, 0),
                        child: _UserStats(users: users),
                      ),
                    ),
                  ),
                  // List header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          20, 20, 20, 12),
                      child: Row(
                        children: [
                          const Text(
                            'All Users',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _indigoSoft,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              filtered.length.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _indigo,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // User cards
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = filtered[index];
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
                                index == filtered.length - 1
                                    ? 100
                                    : 10,
                              ),
                              child: _UserCard(
                                user: user,
                                onEdit: () => _showUserSheet(user),
                                onDelete: () => _showDeleteConfirm(
                                    user.id, user.name),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showUserSheet(null),
          backgroundColor: _gold,
          foregroundColor: _void,
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.person_add_rounded, size: 20),
        ),
      ),
    );
  }
}

// ─── Role Filter Tab Delegate ─────────────────────────────────────────────────
class _RoleTabDelegate extends SliverPersistentHeaderDelegate {
  final List<dynamic> users;
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleTabDelegate({
    required this.users,
    required this.selected,
    required this.onChanged,
  });

  static const _void    = Color(0xFF09090F);
  static const _panel   = Color(0xFF16161F);
  static const _border  = Color(0x18FFFFFF);
  static const _inkMid  = Color(0xFF8B8BA8);
  static const _gold    = Color(0xFFF5C842);

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;
  @override
  bool shouldRebuild(_RoleTabDelegate old) =>
      old.selected != selected || old.users.length != users.length;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final tabs = [
      ('All', 'all', users.length, _gold),
      ('Admin', 'super_admin',
          users.where((u) => u.role == 'super_admin').length,
          const Color(0xFFFF5F6D)),
      ('Owner', 'owner',
          users.where((u) => u.role == 'owner').length,
          const Color(0xFF00D9A3)),
      ('Cashier', 'cashier',
          users.where((u) => u.role == 'cashier').length,
          const Color(0xFF7B68EE)),
    ];

    return Container(
      color: _void,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              children: tabs.map((tab) {
                final isSelected = selected == tab.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChanged(tab.$2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tab.$4.withValues(alpha: 0.12)
                            : _panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected ? tab.$4 : _border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tab.$1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? tab.$4 : _inkMid,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tab.$4.withValues(alpha: 0.2)
                                  : const Color(0x18FFFFFF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tab.$3.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? tab.$4
                                    : _inkMid,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(height: 1, color: _border),
        ],
      ),
    );
  }
}

// ─── User Stats ───────────────────────────────────────────────────────────────
class _UserStats extends StatelessWidget {
  final List<dynamic> users;
  const _UserStats({required this.users});

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        'Total',
        users.length,
        Icons.people_alt_rounded,
        const Color(0xFF7B68EE),
        const Color(0x1F7B68EE)
      ),
      (
        'Admins',
        users.where((u) => u.role == 'super_admin').length,
        Icons.admin_panel_settings_rounded,
        const Color(0xFFFF5F6D),
        const Color(0x1AFF5F6D)
      ),
      (
        'Owners',
        users.where((u) => u.role == 'owner').length,
        Icons.manage_accounts_rounded,
        const Color(0xFF00D9A3),
        const Color(0x1A00D9A3)
      ),
      (
        'Cashiers',
        users.where((u) => u.role == 'cashier').length,
        Icons.point_of_sale_rounded,
        const Color(0xFFFF9F43),
        const Color(0x1FFF9F43)
      ),
    ];

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,     
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: stats.length,
        itemBuilder: (_, i) {
          final s = stats[i];
          return Container(
            width: 100,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x18FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: s.$5,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(s.$3, color: s.$4, size: 14),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.$2.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0F0FF),
                        height: 1.1,
                      ),
                    ),
                    Text(
                      s.$1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF4A4A62),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── User Card ────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _roleColor {
    switch ((user.role as String).toLowerCase()) {
      case 'super_admin':
        return const Color(0xFFFF5F6D);
      case 'owner':
        return const Color(0xFF00D9A3);
      case 'cashier':
        return const Color(0xFF7B68EE);
      default:
        return const Color(0xFF8B8BA8);
    }
  }

  String get _roleLabel {
    switch ((user.role as String).toLowerCase()) {
      case 'super_admin':
        return 'Admin';
      case 'owner':
        return 'Owner';
      case 'cashier':
        return 'Cashier';
      default:
        return user.role as String;
    }
  }

  String get _initials {
    final name = (user.name as String).trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    return parts.map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _roleColor.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _roleColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user.name as String).isNotEmpty
                          ? user.name as String
                          : 'Unnamed',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF0F0FF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4A4A62),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _roleColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _roleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _roleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0x18FFFFFF)),
          const SizedBox(height: 12),
          // Joined date
          if (user.createdAt != null)
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: Color(0xFF4A4A62)),
                const SizedBox(width: 6),
                Text(
                  'Joined ${_fmtDate(user.createdAt as DateTime)}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF8B8BA8)),
                ),
              ],
            ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              Expanded(
                child: _CardBtn(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF00D9A3),
                  bg: const Color(0x1A00D9A3),
                  onTap: onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardBtn(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFFF5F6D),
                  bg: const Color(0x1AFF5F6D),
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── States ───────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Color(0x1AFF5F6D), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  size: 36, color: Color(0xFFFF5F6D)),
            ),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF8B8BA8)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C28),
                foregroundColor: const Color(0xFFF0F0FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 52,
                color: const Color(0xFF4A4A62).withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF4A4A62)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5C842),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Add First User',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF09090F),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchBar(
      {required this.controller,
      required this.onChanged,
      required this.onClose});

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
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFFF0F0FF)),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle:
                    const TextStyle(color: Color(0xFF4A4A62)),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 16, color: Color(0xFF4A4A62)),
                filled: true,
                fillColor: const Color(0xFF16161F),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0x18FFFFFF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0x18FFFFFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFFF5C842), width: 1.5),
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
              color: const Color(0xFF16161F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x18FFFFFF)),
            ),
            child: const Icon(Icons.close_rounded,
                size: 14, color: Color(0xFF8B8BA8)),
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
          color: const Color(0xFF16161F),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0x18FFFFFF)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF8B8BA8)),
      ),
    );
  }
}

// ─── User Form Bottom Sheet ───────────────────────────────────────────────────
class _UserFormSheet extends StatefulWidget {
  final dynamic user;
  final Function(Map<String, dynamic> data) onSave;

  const _UserFormSheet({this.user, required this.onSave});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedRole = 'cashier';
  bool _obscure = true;

  static const _card    = Color(0xFF1C1C28);
  static const _panel   = Color(0xFF16161F);
  static const _border  = Color(0x18FFFFFF);
  static const _ink     = Color(0xFFF0F0FF);
  static const _inkDim  = Color(0xFF4A4A62);
  static const _inkMid  = Color(0xFF8B8BA8);
  static const _gold    = Color(0xFFF5C842);
  static const _goldSoft = Color(0x20F5C842);
  static const _void    = Color(0xFF09090F);
  static const _coral   = Color(0xFFFF5F6D);

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameCtrl.text = widget.user.name ?? '';
      _emailCtrl.text = widget.user.email ?? '';
      _selectedRole = widget.user.role ?? 'cashier';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _inkDim,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _goldSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      isEdit
                          ? Icons.edit_rounded
                          : Icons.person_add_rounded,
                      color: _gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit User' : 'New User',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const Text('Fill in the details',
                          style: TextStyle(
                              fontSize: 11, color: _inkDim)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _FormInput(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _FormInput(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Required';
                  if (!v!.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Role selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _inkDim,
                      letterSpacing: 0.08,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ('super_admin', 'Admin',
                          Icons.admin_panel_settings_rounded,
                          const Color(0xFFFF5F6D)),
                      ('owner', 'Owner',
                          Icons.manage_accounts_rounded,
                          const Color(0xFF00D9A3)),
                      ('cashier', 'Cashier',
                          Icons.point_of_sale_rounded,
                          const Color(0xFF7B68EE)),
                    ].asMap().entries.map((e) {
                      final idx = e.key;
                      final role = e.value;
                      final isSelected = _selectedRole == role.$1;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: idx < 2 ? 8 : 0),
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _selectedRole = role.$1),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? role.$4.withValues(alpha: 0.12)
                                    : _panel,
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? role.$4
                                      : _border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(role.$3,
                                      color: isSelected
                                          ? role.$4
                                          : _inkMid,
                                      size: 16),
                                  const SizedBox(height: 3),
                                  Text(
                                    role.$2,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? role.$4
                                          : _inkMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FormInput(
                controller: _passwordCtrl,
                label: isEdit
                    ? 'New Password (leave blank to keep)'
                    : 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                    color: _inkMid,
                  ),
                ),
                validator: isEdit
                    ? null
                    : (v) {
                        if (v?.trim().isEmpty ?? true) {
                          return 'Required';
                        }
                        if ((v?.length ?? 0) < 8) {
                          return 'Min 8 characters';
                        }
                        return null;
                      },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: _inkMid)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final data = <String, dynamic>{
                            'name': _nameCtrl.text.trim(),
                            'email': _emailCtrl.text.trim(),
                            'role': _selectedRole,
                          };
                          if (isEdit) {
                            if (_passwordCtrl.text.isNotEmpty) {
                              data['password'] = _passwordCtrl.text;
                            }
                          } else {
                            data['password'] =
                                _passwordCtrl.text.trim();
                          }
                          widget.onSave(data);
                        }
                      },
                      icon: Icon(
                          isEdit
                              ? Icons.save_rounded
                              : Icons.person_add_rounded,
                          size: 15),
                      label: Text(isEdit ? 'Save Changes' : 'Add User'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _void,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Form Input ───────────────────────────────────────────────────────────────
class _FormInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  static const _panel  = Color(0xFF16161F);
  static const _border = Color(0x18FFFFFF);
  static const _ink    = Color(0xFFF0F0FF);
  static const _inkDim = Color(0xFF4A4A62);
  static const _inkMid = Color(0xFF8B8BA8);
  static const _gold   = Color(0xFFF5C842);
  static const _coral  = Color(0xFFFF5F6D);

  const _FormInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _inkDim,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: _ink),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 15, color: _inkMid),
            suffixIcon: suffix,
            filled: true,
            fillColor: _panel,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _gold, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _coral, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _coral, width: 1.5),
            ),
            errorStyle:
                const TextStyle(fontSize: 11, color: _coral),
          ),
        ),
      ],
    );
  }
}