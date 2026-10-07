import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/product_photo.dart';
import '../bloc/products_bloc.dart';

/// Keyboard-safe add/edit product sheet.
class ProductEditorSheet extends StatefulWidget {
  const ProductEditorSheet({
    super.key,
    this.product,
    this.categories = const [],
    this.categoryLabels = const {},
    this.onNeedCategories,
  });

  final dynamic product;
  final List<String> categories;
  final Map<String, String> categoryLabels;
  final VoidCallback? onNeedCategories;

  static Future<void> show(
    BuildContext context, {
    dynamic product,
    List<String> categories = const [],
    Map<String, String> categoryLabels = const {},
    VoidCallback? onNeedCategories,
  }) {
    final bloc = context.read<ProductsBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: ProductEditorSheet(
          product: product,
          categories: categories,
          categoryLabels: categoryLabels,
          onNeedCategories: onNeedCategories,
        ),
      ),
    );
  }

  @override
  State<ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<ProductEditorSheet> {
  Color get _navy => BrandTokens.current.primary;
  Color get _navyLight => BrandTokens.current.primaryLt;
  Color get _slate => BrandTokens.current.inkMid;
  Color get _slateLight => BrandTokens.current.border;
  Color get _bg => BrandTokens.current.bg;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _thresholdCtrl;
  String? _selectedCategory;
  String? _pickedImagePath;

  bool get _isEditing => widget.product != null;
  List<String> get _categoryOptions {
    final names = {...widget.categories};
    final current = _categoryCtrl.text.trim();
    if (current.isNotEmpty) names.add(current);
    final list = names.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: '${p?.name ?? ''}');
    _barcodeCtrl = TextEditingController(text: '${p?.barcode ?? ''}');
    _priceCtrl = TextEditingController(text: p?.price == null ? '' : '${p.price}');
    _stockCtrl = TextEditingController(text: p?.stock == null ? '10' : '${p.stock}');
    final initialCat = '${p?.category ?? ''}'.trim();
    _categoryCtrl = TextEditingController(
      text: initialCat.isNotEmpty
          ? initialCat
          : (widget.categories.isNotEmpty ? widget.categories.first : ''),
    );
    _selectedCategory = _categoryCtrl.text.isEmpty ? null : _categoryCtrl.text;
    _thresholdCtrl = TextEditingController(
      text: p?.lowStockThreshold == null ? '10' : '${p.lowStockThreshold}',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _categoryCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final threshold = int.tryParse(_thresholdCtrl.text.trim()) ?? 10;
    final barcode = _barcodeCtrl.text.trim();
    final category = (_selectedCategory ?? _categoryCtrl.text).trim();
    if (category.isEmpty) return;

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      // Backend accepts null for products without a barcode.
      'barcode': barcode.isEmpty ? null : barcode,
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'stock': int.tryParse(_stockCtrl.text.trim()) ?? 0,
      'category': category,
      'lowStockThreshold': threshold,
      'low_stock_threshold': threshold,
    };
    if (_pickedImagePath != null) {
      data['image_path'] = _pickedImagePath;
    }

    final bloc = context.read<ProductsBloc>();
    if (_isEditing) {
      bloc.add(ProductUpdateRequested(widget.product.id, data));
    } else {
      bloc.add(ProductCreateRequested(data));
    }
    Navigator.of(context).pop();
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      filled: true,
      fillColor: _bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _slateLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _slateLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: _navy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;
    setState(() => _pickedImagePath = picked.path);
  }

  Widget _buildPhotoPicker(AppStrings t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.productPhoto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _pickedImagePath != null
                  ? Image.file(
                      File(_pickedImagePath!),
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    )
                  : ProductPhoto(
                      url: widget.product?.image as String?,
                      size: 88,
                      radius: 14,
                      iconSize: 32,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(t.choosePhoto),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(t.takePhoto),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _labeledField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 14, color: _navy),
          decoration: _decoration(hint ?? ''),
        ),
      ],
    );
  }

  Widget _buildCategoryField(AppStrings t) {
    final options = _categoryOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t.categoryCol} *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 6),
        if (options.isNotEmpty)
          DropdownButtonFormField<String>(
            value: options.contains(_selectedCategory)
                ? _selectedCategory
                : null,
            items: options
                .map(
                  (name) => DropdownMenuItem(
                    value: name,
                    child: Text(
                      widget.categoryLabels[name] ?? name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedCategory = v;
                _categoryCtrl.text = v ?? '';
              });
            },
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t.categoryRequired : null,
            decoration: _decoration(t.selectCategory),
            style: TextStyle(fontSize: 14, color: _navy),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(10),
          )
        else ...[
          TextFormField(
            controller: _categoryCtrl,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t.categoryRequired : null,
            style: TextStyle(fontSize: 14, color: _navy),
            decoration: _decoration(t.categoryHint),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              widget.onNeedCategories?.call();
            },
            child: Text(
              t.addCategoriesFirst,
              style: TextStyle(
                fontSize: 12,
                color: _navy,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _slateLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_navy, _navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        _isEditing ? Icons.edit_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEditing ? t.editProduct : t.addNewProduct,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPhotoPicker(t),
                        const SizedBox(height: 16),
                        _labeledField(
                          label: t.productNameRequired,
                          controller: _nameCtrl,
                          hint: t.productNameHint,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? t.requiredField
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: t.barcodeOptional,
                          controller: _barcodeCtrl,
                          hint: t.barcodeHintOptional,
                        ),
                        const SizedBox(height: 14),
                        _buildCategoryField(t),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: t.priceTzsRequired,
                          controller: _priceCtrl,
                          hint: '0',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n < 0) {
                              return t.enterValidPrice;
                            }
                            return null;
                          },
                        ),
                        if (widget.product?.cost != null) ...[
                          const SizedBox(height: 14),
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: t.lastCost,
                              border: const OutlineInputBorder(),
                            ),
                            child: Text(
                              CurrencyFormatter.format(widget.product!.cost!),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: BrandTokens.current.ink,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _labeledField(
                          label: t.stockQuantity,
                          controller: _stockCtrl,
                          hint: '0',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        _labeledField(
                          label: t.lowStockAlertAt,
                          controller: _thresholdCtrl,
                          hint: '10',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: _bg,
                  border: Border(
                    top: BorderSide(color: _slateLight),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _slate,
                            side: BorderSide(color: _slateLight),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            t.cancel,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: Icon(
                            _isEditing
                                ? Icons.save_rounded
                                : Icons.add_rounded,
                            size: 16,
                          ),
                          label: Text(
                            _isEditing ? t.saveChanges : t.addProduct,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
