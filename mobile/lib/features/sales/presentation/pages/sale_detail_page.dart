import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/sale_entity.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';

/// Sale detail — navy / teal tokens matching Dashboard, Reports, Sales list.
class SaleDetailPage extends StatefulWidget {
  final String saleId;
  const SaleDetailPage({super.key, required this.saleId});

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _D {
  static const bg = Color(0xFFF5F6FA);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1E3A5F);
  static const primaryLt = Color(0xFF2B527A);
  static const accent = Color(0xFF00C896);
  static const accentSoft = Color(0x1A00C896);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0x1A3B82F6);
  static const ink = Color(0xFF1A2332);
  static const inkMid = Color(0xFF64748B);
  static const border = Color(0xFFE8EDF5);

  static TextStyle ts(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = ink,
  }) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
}

class _SaleDetailPageState extends State<SaleDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  SaleEntity? _sale;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    // Prefer sale already in the list so UI isn't blank while detail loads.
    final current = context.read<SalesBloc>().state;
    if (current is SalesLoaded) {
      for (final s in current.sales) {
        if (s.id == widget.saleId) {
          _sale = s;
          break;
        }
      }
    }
    if (_sale != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animController.forward();
      });
    }

    context.read<SalesBloc>().add(SaleDetailRequested(widget.saleId));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _applySale(SaleEntity sale) {
    if (!mounted) return;
    setState(() {
      _sale = sale;
      _error = null;
    });
    if (_animController.status != AnimationStatus.completed) {
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _D.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_D.primary, _D.primaryLt],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice Details',
                            style: _D.ts(17,
                                weight: FontWeight.w700, color: Colors.white)),
                        Text('Sale receipt & line items',
                            style: _D.ts(11, color: Colors.white60)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocListener<SalesBloc, SalesState>(
                listener: (context, state) {
                  if (state is SaleDetailLoaded &&
                      state.sale.id == widget.saleId) {
                    _applySale(state.sale);
                  } else if (state is SalesError && _sale == null) {
                    setState(() => _error = state.message);
                  }
                },
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_sale != null) {
      return FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: _SaleDetailBody(sale: _sale!),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  style: _D.ts(13, color: _D.inkMid),
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  context
                      .read<SalesBloc>()
                      .add(SaleDetailRequested(widget.saleId));
                },
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _D.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(
        color: _D.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _SaleDetailBody extends StatelessWidget {
  const _SaleDetailBody({required this.sale});

  final SaleEntity sale;

  @override
  Widget build(BuildContext context) {
    final s = sale;
    final vatLabel = s.taxType.isEmpty ? 'Tax' : 'VAT (${s.taxType})';
    final customer = s.customerName?.trim();
    final showCustomer = customer != null &&
        customer.isNotEmpty &&
        customer.toLowerCase() != 'walk-in customer' &&
        customer.toLowerCase() != 'walk-in';
    final pay = s.paymentMethod.isEmpty
        ? 'N/A'
        : s.paymentMethod[0].toUpperCase() +
            s.paymentMethod.substring(1).toLowerCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _D.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: _D.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.invoiceNo.isNotEmpty
                                ? s.invoiceNo
                                : '#${s.id}',
                            style: _D.ts(17, weight: FontWeight.w800),
                          ),
                          Text(
                            DateFormatter.formatDateTime(s.createdAt),
                            style: _D.ts(12, color: _D.inkMid),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _D.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.status.isEmpty
                            ? 'Completed'
                            : s.status[0].toUpperCase() +
                                s.status.substring(1),
                        style: _D.ts(11,
                            weight: FontWeight.w700, color: _D.accent),
                      ),
                    ),
                  ],
                ),
                if (showCustomer) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: _D.border),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 16, color: _D.inkMid),
                      const SizedBox(width: 6),
                      Text('Customer', style: _D.ts(12, color: _D.inkMid)),
                      const Spacer(),
                      Text(customer,
                          style: _D.ts(13, weight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Order Items',
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _D.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text('Product',
                            style: _D.ts(11,
                                weight: FontWeight.w600, color: _D.inkMid)),
                      ),
                      SizedBox(
                        width: 52,
                        child: Text('Qty',
                            style: _D.ts(11,
                                weight: FontWeight.w600, color: _D.inkMid),
                            textAlign: TextAlign.center),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text('Amount',
                            style: _D.ts(11,
                                weight: FontWeight.w600, color: _D.inkMid),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (s.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No line items on this sale',
                        style: _D.ts(13, color: _D.inkMid)),
                  )
                else
                  ...s.items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        border: i < s.items.length - 1
                            ? const Border(
                                bottom: BorderSide(color: _D.border))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              item.productName,
                              style: _D.ts(13, weight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _D.infoSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${item.quantity}',
                                  style: _D.ts(12,
                                      weight: FontWeight.w600, color: _D.info),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              CurrencyFormatter.format(item.subtotal),
                              style: _D.ts(13, weight: FontWeight.w600),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              children: [
                _TotalRow(
                  label: 'Subtotal',
                  value: CurrencyFormatter.format(s.subtotal),
                  icon: Icons.calculate_outlined,
                ),
                const SizedBox(height: 8),
                _TotalRow(
                  label: vatLabel,
                  value: CurrencyFormatter.format(s.totalVat),
                  icon: Icons.percent_rounded,
                ),
                if (s.discount > 0) ...[
                  const SizedBox(height: 8),
                  _TotalRow(
                    label: 'Discount',
                    value: '-${CurrencyFormatter.format(s.discount)}',
                    icon: Icons.local_offer_outlined,
                    valueColor: _D.accent,
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_D.primary, _D.primaryLt],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount',
                          style: _D.ts(14, color: Colors.white70)),
                      Text(
                        CurrencyFormatter.format(s.total),
                        style: _D.ts(18,
                            weight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _D.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: _D.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Payment Method', style: _D.ts(13, color: _D.inkMid)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _D.accentSoft,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _D.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    pay,
                    style: _D.ts(13,
                        weight: FontWeight.w700, color: _D.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _D.cardShadow,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _D.primary),
        const SizedBox(width: 6),
        Text(label, style: _D.ts(14, weight: FontWeight.w700)),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _D.inkMid),
        const SizedBox(width: 8),
        Text(label, style: _D.ts(13, color: _D.inkMid)),
        const Spacer(),
        Text(
          value,
          style: _D.ts(13,
              weight: FontWeight.w600, color: valueColor ?? _D.ink),
        ),
      ],
    );
  }
}
