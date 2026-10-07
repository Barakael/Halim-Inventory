import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/router/route_names.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../products/presentation/bloc/products_bloc.dart';

class LowStockAlertWidget extends StatelessWidget {
  const LowStockAlertWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Low Stock Alerts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                if (state is ProductsLoading) {
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                } else if (state is ProductsLoaded) {
                  // FIX: null-safe lowStockThreshold comparison
                  final lowStockProducts = state.products
                      .where((product) =>
                          product.stock <= (product.lowStockThreshold ?? 10))
                      .take(5)
                      .toList();

                  if (lowStockProducts.isEmpty) {
                    return Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All products well stocked',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      ...lowStockProducts
                          .map((product) => _LowStockItem(product: product)),
                      // FIX: null-safe comparison here too
                      if (state.products
                              .where((p) =>
                                  p.stock <= (p.lowStockThreshold ?? 10))
                              .length >
                          5)
                        TextButton(
                          onPressed: () => context.push(RouteNames.inventory),
                          child: const Text('View all'),
                        ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockItem extends StatelessWidget {
  final dynamic product;

  const _LowStockItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock == 0;
    final stockLevel = product.stock;
    final minStock = product.lowStockThreshold ?? 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isOutOfStock
            ? AppColors.error.withAlpha(10)
            : AppColors.warning.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutOfStock
              ? AppColors.error.withAlpha(30)
              : AppColors.warning.withAlpha(30),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isOutOfStock ? AppColors.error : AppColors.warning,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name ?? 'Unknown Product',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Min: $minStock',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isOutOfStock ? 'OUT' : '$stockLevel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOutOfStock ? AppColors.error : AppColors.warning,
                ),
              ),
              Text(
                'left',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}