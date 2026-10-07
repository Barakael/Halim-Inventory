import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../sales/domain/entities/sale_entity.dart';
import '../../../shops/domain/entities/shop_entity.dart';

class ReceiptKv {
  const ReceiptKv(this.label, this.value);
  final String label;
  final String value;
}

class ReceiptItemLine {
  const ReceiptItemLine({
    required this.qty,
    required this.name,
    required this.unitPrice,
    required this.amount,
  });

  final String qty;
  final String name;
  final String unitPrice;
  final String amount;
}

/// Shop receipt used for preview, PDF, H10S, and Bluetooth.
class ReceiptContent {
  const ReceiptContent({
    required this.shopName,
    required this.letterhead,
    required this.shopFacts,
    required this.identifiers,
    required this.customer,
    required this.items,
    required this.totals,
    required this.grandTotal,
    required this.payment,
    required this.receiptNo,
  });

  final String shopName;
  final List<String> letterhead;
  final List<ReceiptKv> shopFacts;
  final List<ReceiptKv> identifiers;
  final List<ReceiptKv> customer;
  final List<ReceiptItemLine> items;
  final List<ReceiptKv> totals;
  final String grandTotal;
  final List<ReceiptKv> payment;
  final String receiptNo;

  factory ReceiptContent.from({
    required SaleEntity sale,
    required ShopEntity shop,
  }) {
    final dec = CurrencyFormatter.formatTraDecimal;
    final receiptNo =
        sale.serialNumber.isNotEmpty ? sale.serialNumber : 'RCP-${sale.id}';
    final when = sale.createdAt.toLocal();

    final tendered =
        sale.amountTendered > 0 ? sale.amountTendered : sale.total;
    final change = sale.cashChange >= 0
        ? sale.cashChange
        : (tendered - sale.total).clamp(0, double.infinity);

    final letterhead = <String>[];
    if (!_blank(shop.address)) letterhead.add(shop.address.trim());
    if (!_blank(shop.location)) letterhead.add(shop.location.trim());

    final tel = !_blank(shop.mobile)
        ? shop.mobile
        : (!_blank(shop.phone) ? shop.phone : null);

    final shopFacts = <ReceiptKv>[
      if (!_blank(tel)) ReceiptKv('TEL', tel!),
    ];

    final identifiers = <ReceiptKv>[
      ReceiptKv('RECEIPT', receiptNo),
      ReceiptKv(
        'DATE',
        '${DateFormat('dd/MM/yyyy').format(when)}  '
        '${DateFormat('HH:mm:ss').format(when)}',
      ),
    ];

    final customer = <ReceiptKv>[
      if (!_blank(sale.customerName)) ReceiptKv('Name', sale.customerName!),
      if (!_blank(sale.customerPhone)) ReceiptKv('Mobile', sale.customerPhone!),
      if (!_blank(sale.customerAddress))
        ReceiptKv('Address', sale.customerAddress!),
    ];

    final items = sale.items
        .map(
          (item) => ReceiptItemLine(
            qty: '${item.quantity}x',
            name: item.productName.trim(),
            unitPrice: dec(item.unitPrice),
            amount: dec(item.subtotal),
          ),
        )
        .toList();

    final totals = <ReceiptKv>[
      ReceiptKv('Subtotal', dec(sale.subtotal)),
      if (sale.discount > 0) ReceiptKv('Discount', '-${dec(sale.discount)}'),
    ];

    return ReceiptContent(
      shopName: shop.name.trim().toUpperCase(),
      letterhead: letterhead,
      shopFacts: shopFacts,
      identifiers: identifiers,
      customer: customer,
      items: items,
      totals: totals,
      grandTotal: dec(sale.total),
      payment: [
        ReceiptKv(_payLabel(sale.paymentMethod), dec(tendered)),
        ReceiptKv('Change', dec(change)),
      ],
      receiptNo: receiptNo,
    );
  }

  static bool _blank(String? value) {
    if (value == null) return true;
    final v = value.trim();
    if (v.isEmpty) return true;
    final lower = v.toLowerCase();
    return lower == 'walk-in customer' ||
        lower == 'walk in customer' ||
        lower == 'n/a' ||
        lower == 'null' ||
        v == '0000000000';
  }

  static String _payLabel(String method) {
    switch (method.toLowerCase().trim()) {
      case 'cash':
        return 'Cash tendered';
      case 'card':
        return 'Card payment';
      case 'mobile':
      case 'mobile_money':
      case 'mpesa':
        return 'Mobile payment';
      case 'credit':
        return 'Credit / debt';
      default:
        return method.isEmpty ? 'Amount paid' : method;
    }
  }
}
