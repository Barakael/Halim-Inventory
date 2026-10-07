import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/categories_api.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/product_photo.dart';
import '../bloc/products_bloc.dart';
import '../widgets/product_editor_sheet.dart';

Color get _navy => BrandTokens.current.primary;
Color get _navyLight => BrandTokens.current.primaryLt;
Color get _slate => BrandTokens.current.inkMid;
Color get _slateLight => BrandTokens.current.border;
Color get _bg => BrandTokens.current.bg;
Color get _success => BrandTokens.current.accent;
Color get _danger => BrandTokens.current.danger;
Color get _amber => BrandTokens.current.warn;

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key});

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _categoryCtrl = TextEditingController();
  late final TabController _tabs;
  late final CategoriesApi _categoriesApi;

  String _searchQuery = '';
  String _filter = 'all';
  /// null = all categories; otherwise exact category name (or parent = includes children).
  String? _categoryFilter;
  List<ShopCategory> _categories = [];
  bool _catsLoading = true;
  bool _catSaving = false;
  String? _catsError;
  int? _newCategoryParentId;

  @override
  void initState() {
    super.initState();
    _categoriesApi = sl<CategoriesApi>();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted && !_tabs.indexIsChanging) {
        setState(() {});
      }
    });
    // Defer bloc/API calls so first frame isn't mid-layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductsBloc>().add(const ProductsFetchRequested());
      _loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _catsLoading = true;
      _catsError = null;
    });
    try {
      final list = await _categoriesApi.getAll();
      if (!mounted) return;
      setState(() {
        _categories = list;
        _catsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catsLoading = false;
        _catsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _addCategory([String? name]) async {
    final t = context.t;
    final trimmed = (name ?? _categoryCtrl.text).trim();
    if (trimmed.isEmpty || _catSaving) return;
    setState(() => _catSaving = true);
    try {
      // Unsaved pills / quick-add stay top-level; form uses _newCategoryParentId.
      final parentId = name != null ? null : _newCategoryParentId;
      await _categoriesApi.create(trimmed, parentId: parentId);
      if (!mounted) return;
      _categoryCtrl.clear();
      setState(() => _newCategoryParentId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.categoryAdded),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _catSaving = false);
    }
  }

  List<ShopCategory> get _rootCategories =>
      _categories.where((c) => c.isRoot).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<ShopCategory> _childrenOf(int parentId) =>
      _categories.where((c) => c.parentId == parentId).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  String? _parentNameOf(ShopCategory cat) {
    if (cat.parentId == null) return null;
    for (final c in _categories) {
      if (c.id == cat.parentId) return c.name;
    }
    return null;
  }

  bool _productMatchesCategoryFilter(dynamic product) {
    if (_categoryFilter == null) return true;
    final cat = (product.category as String?)?.trim() ?? '';
    if (cat == _categoryFilter) return true;
    // Parent filter includes its subcategories.
    ShopCategory? parent;
    for (final c in _categories) {
      if (c.name == _categoryFilter && c.isRoot) {
        parent = c;
        break;
      }
    }
    if (parent == null) return false;
    return _childrenOf(parent.id).any((c) => c.name == cat);
  }

  Future<void> _deleteCategory(ShopCategory cat) async {
    final t = context.t;
    final kids = _childrenOf(cat.id);
    if (kids.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.deleteSubcategoriesFirst),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteCategory),
        content: Text('${t.delete} "${cat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _categoriesApi.delete(cat.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.categoryDeleted),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: _navy,
              unselectedLabelColor: _slate,
              indicatorColor: _navy,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  text: t.productsTab,
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: const Icon(Icons.category_outlined, size: 18),
                  text: t.categories,
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                BlocConsumer<ProductsBloc, ProductsState>(
                  listener: _handleStateChanges,
                  builder: (context, state) {
                    final products = state is ProductsLoaded
                        ? state.products
                        : const <dynamic>[];
                    return Column(
                      children: [
                        _buildSearchAndFilter(products: products),
                        Expanded(child: _buildBody(context, state)),
                      ],
                    );
                  },
                ),
                _buildCategoriesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final onProducts = _tabs.index == 0;
    return AppBar(
      elevation: 0,
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      toolbarHeight: 64,
      title: BlocBuilder<ProductsBloc, ProductsState>(
        builder: (context, state) {
          final t = context.t;
          final subtitle = onProducts
              ? (state is ProductsLoaded
                  ? t.inventorySubtitle(
                      state.products.length,
                      state.products.fold<int>(0, (s, p) => s + p.stock),
                    )
                  : t.loadingInventory)
              : t.yourCategories;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.inventory,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        if (onProducts)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showProductDialog(context, null),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: Text(
                context.t.addProduct,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        else
          IconButton(
            tooltip: context.t.addNewCategory,
            onPressed: _catsLoading ? null : () => _focusAddCategory(),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
          ),
      ],
    );
  }

  void _focusAddCategory() {
    // Form is pinned at top of Categories tab.
  }

  List<Widget> _buildCategoryTreeTiles(
      List<dynamic> products, AppStrings t) {
    final tiles = <Widget>[];
    for (final root in _rootCategories) {
      final rootCount = products
          .where((p) => (p.category as String?)?.trim() == root.name)
          .length;
      final children = _childrenOf(root.id);
      tiles.add(
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.folder_outlined, color: _navy, size: 18),
          ),
          title: Text(
            root.name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _navy,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            children.isEmpty
                ? t.productsCount(rootCount)
                : '${t.productsCount(rootCount)} · ${t.subcategoriesCount(children.length)}',
            style: TextStyle(fontSize: 12, color: _slate),
          ),
          trailing: IconButton(
            tooltip: t.deleteCategory,
            onPressed: () => _deleteCategory(root),
            icon: Icon(Icons.delete_outline_rounded,
                color: _danger, size: 20),
          ),
        ),
      );
      tiles.add(Divider(height: 1, color: _slateLight));
      for (final child in children) {
        final childCount = products
            .where((p) => (p.category as String?)?.trim() == child.name)
            .length;
        tiles.add(
          ListTile(
            contentPadding:
                const EdgeInsets.fromLTRB(36, 2, 16, 2),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.subdirectory_arrow_right_rounded,
                  color: _navy, size: 16),
            ),
            title: Text(
              child.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _navy,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              t.productsCount(childCount),
              style: TextStyle(fontSize: 11, color: _slate),
            ),
            trailing: IconButton(
              tooltip: t.deleteCategory,
              onPressed: () => _deleteCategory(child),
              icon: Icon(Icons.delete_outline_rounded,
                  color: _danger, size: 20),
            ),
          ),
        );
        tiles.add(Divider(height: 1, color: _slateLight));
      }
    }
    // Orphan children (parent deleted) — rare with nullOnDelete
    final rootIds = _rootCategories.map((c) => c.id).toSet();
    final orphans = _categories
        .where((c) => c.parentId != null && !rootIds.contains(c.parentId))
        .toList();
    for (final orphan in orphans) {
      tiles.add(
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(orphan.name),
          subtitle: Text(t.topLevelCategory),
          trailing: IconButton(
            onPressed: () => _deleteCategory(orphan),
            icon: Icon(Icons.delete_outline_rounded, color: _danger),
          ),
        ),
      );
    }
    return tiles;
  }

  Widget _buildCategoriesTab() {
    final t = context.t;
    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        final products =
            state is ProductsLoaded ? state.products : const <dynamic>[];
        final usedNames = products
            .map((p) => (p.category as String?)?.trim() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet();
        final savedNames = _categories.map((c) => c.name).toSet();
        final unsaved =
            usedNames.where((n) => !savedNames.contains(n)).toList()..sort();

        return Column(
          children: [
            // Pinned add form — always visible above the list.
            Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.addNewCategory,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.subcategoryHint,
                      style: TextStyle(fontSize: 12, color: _slate),
                    ),
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: t.parentCategoryOptional,
                        filled: true,
                        fillColor: _bg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _slateLight),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: _newCategoryParentId,
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(t.topLevelCategory),
                            ),
                            ..._rootCategories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _newCategoryParentId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _categoryCtrl,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addCategory(),
                            style: TextStyle(fontSize: 14, color: _navy),
                            decoration: InputDecoration(
                              hintText: t.categoryNameHint,
                              hintStyle:
                                  TextStyle(fontSize: 13, color: _slate),
                              filled: true,
                              fillColor: _bg,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: _slateLight),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: _slateLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: _navy, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Override theme minimumSize: Size(infinity) which
                        // breaks Row layout and can hide this form.
                        Material(
                          color: _navy,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _catSaving ? null : () => _addCategory(),
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 44,
                              width: 88,
                              child: Center(
                                child: _catSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add_rounded,
                                              size: 18, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            t.create,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: _slateLight),
            Expanded(
              child: RefreshIndicator(
                color: _navy,
                onRefresh: _loadCategories,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _slateLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: Row(
                              children: [
                                Text(
                                  t.yourCategories,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _navy,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${_categories.length})',
                                  style:
                                      TextStyle(fontSize: 12, color: _slate),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: _slateLight),
                          if (_catsLoading)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: AppLoadingIndicator()),
                            )
                          else if (_catsError != null)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Text(
                                    _catsError!,
                                    style: TextStyle(
                                        color: _danger, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _loadCategories,
                                    child: Text(t.retry),
                                  ),
                                ],
                              ),
                            )
                          else if (_categories.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 36, horizontal: 24),
                              child: Column(
                                children: [
                                  Icon(Icons.category_outlined,
                                      size: 36, color: _slateLight),
                                  const SizedBox(height: 10),
                                  Text(
                                    t.noCategoriesYet,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _slate,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.addFirstCategory,
                                    style: TextStyle(
                                        fontSize: 12, color: _slate),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._buildCategoryTreeTiles(products, t),
                        ],
                      ),
                    ),
                    if (unsaved.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _slateLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.unsavedCategoriesHint,
                              style: TextStyle(fontSize: 12, color: _slate),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final name in unsaved)
                                  ActionChip(
                                    label: Text(name),
                                    avatar: Icon(Icons.add_rounded,
                                        size: 16, color: _navy),
                                    onPressed: _catSaving
                                        ? null
                                        : () => _addCategory(name),
                                    backgroundColor: _bg,
                                    side: BorderSide(color: _slateLight),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _categoryNamesForFilter(List<dynamic> products) {
    final fromProducts = products
        .map((p) => (p.category as String?)?.trim() ?? '')
        .where((n) => n.isNotEmpty);
    final fromApi = _categories.map((c) => c.name.trim()).where((n) => n.isNotEmpty);
    final names = {...fromProducts, ...fromApi}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Widget _buildSearchAndFilter({List<dynamic> products = const []}) {
    final t = context.t;
    final categories = _categoryNamesForFilter(products);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _slateLight),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 14, color: _navy),
              decoration: InputDecoration(
                hintText: t.searchInventoryHint,
                hintStyle: TextStyle(fontSize: 13, color: _slate),
                prefixIcon:
                    Icon(Icons.search_rounded, color: _slate, size: 18),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              ),
              onChanged: (value) {
                // Local filter only — includes name, barcode, and category.
                setState(() => _searchQuery = value);
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _filterChip('all', t.allProducts, Icons.grid_view_rounded),
              const SizedBox(width: 8),
              _filterChip('low', t.lowStock, Icons.warning_amber_rounded),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _categoryChip(
                      label: t.allCategories,
                      selected: _categoryFilter == null,
                      onTap: () => setState(() => _categoryFilter = null),
                    );
                  }
                  final name = categories[index - 1];
                  return _categoryChip(
                    label: name,
                    selected: _categoryFilter == name,
                    onTap: () => setState(() {
                      _categoryFilter =
                          _categoryFilter == name ? null : name;
                    }),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _navyLight.withValues(alpha: 0.35) : _bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _navy : _slateLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? _navy : _slate,
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final active = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          decoration: BoxDecoration(
            color: active ? _navy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? _navy : _slateLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active
                    ? Colors.white
                    : (value == 'low' ? _amber : _slate),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProductsState state) {
    return switch (state) {
      ProductsLoading() => const Center(child: AppLoadingIndicator()),
      ProductsError(message: final msg) => ErrorView(
          message: msg,
          onRetry: () => context
              .read<ProductsBloc>()
              .add(const ProductsFetchRequested()),
        ),
      ProductsLoaded(products: final products) when products.isEmpty =>
          _buildEmptyState(),
      ProductsLoaded(products: final products) =>
          _buildTable(context, products),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildEmptyState() {
    final t = context.t;
    final searching = _searchQuery.isNotEmpty ||
        _filter == 'low' ||
        _categoryFilter != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      searching
                          ? Icons.search_off_rounded
                          : Icons.inventory_2_outlined,
                      size: 28,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    searching
                        ? (_searchQuery.isNotEmpty
                            ? t.noResultsFor(_searchQuery)
                            : t.noProductsFound)
                        : t.noProductsYet,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    searching ? t.tryDifferentName : t.addFirstProduct,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: _slate),
                  ),
                  if (!searching) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      child: AppButton(
                        label: t.addNewProduct,
                        onPressed: () => _showProductDialog(context, null),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTable(BuildContext context, List<dynamic> allProducts) {
    final products = _getFilteredProducts(allProducts);
    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = products[index];
        final isLowStock = product.isLowStock ?? false;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _showProductDialog(context, product),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _slateLight),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ProductPhoto(
                    url: product.image as String?,
                    size: 72,
                    radius: 14,
                    iconSize: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _navy.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                product.category ?? context.t.generalCategory,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _navyLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isLowStock ? _danger : _success)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${product.stock}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isLowStock ? _danger : _success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CurrencyFormatter.format(product.price),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.edit_rounded,
                    color: _navyLight,
                    tooltip: context.t.edit,
                    onTap: () => _showProductDialog(context, product),
                  ),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: _danger,
                    tooltip: context.t.delete,
                    onTap: () =>
                        _showDeleteConfirm(context, product.id, product.name),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<dynamic> _getFilteredProducts(List<dynamic> products) {
    return products.where((product) {
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          product.name.toLowerCase().contains(q) ||
          (product.barcode?.toString().toLowerCase().contains(q) ?? false) ||
          (product.category?.toLowerCase().contains(q) ?? false);
      final matchesStock = _filter == 'all' || (product.isLowStock ?? false);
      final matchesCategory = _productMatchesCategoryFilter(product);
      return matchesSearch && matchesStock && matchesCategory;
    }).toList();
  }

  void _handleStateChanges(BuildContext context, ProductsState state) {
    if (state is ProductActionSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(state.message),
            ],
          ),
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      context.read<ProductsBloc>().add(const ProductsFetchRequested());
      _loadCategories();
    } else if (state is ProductsError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showProductDialog(BuildContext context, dynamic product) {
    ProductEditorSheet.show(
      context,
      product: product,
      categories: _categories.map((c) => c.name).toList(),
      categoryLabels: {
        for (final c in _categories)
          c.name: _parentNameOf(c) == null
              ? c.name
              : '${_parentNameOf(c)} › ${c.name}',
      },
      onNeedCategories: () {
        _tabs.animateTo(1);
        _loadCategories();
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, String id, String name) {
    final t = AppStrings.read(context);
    final productId = id.trim();
    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.cannotDeleteMissingId),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final bloc = context.read<ProductsBloc>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dt = ctx.t;
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            color: _danger, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          dt.deleteProduct,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 14, color: _slate, height: 1.5),
                      children: [
                        TextSpan(text: dt.deleteProductConfirm),
                        TextSpan(
                          text: '"$name"',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: _navy),
                        ),
                        TextSpan(text: dt.deleteCannotUndo),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        bloc.add(ProductDeleteRequested(productId));
                      },
                      icon: const Icon(Icons.delete_rounded, size: 18),
                      label: Text(dt.delete,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _slate,
                        side: BorderSide(color: _slateLight),
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                      ),
                      child: Text(dt.cancel,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
