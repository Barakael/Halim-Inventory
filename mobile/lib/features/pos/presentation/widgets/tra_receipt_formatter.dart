import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../sales/domain/entities/sale_entity.dart';
import '../../../shops/domain/entities/shop_entity.dart';
import 'receipt_content.dart';

/// Plain-text 58mm receipt (32 columns) for the on-screen preview.
class TraReceiptFormatter {
  TraReceiptFormatter._();

  static const int lineWidth = 32;

  static const int _qtyCol = 4;
  static const int _amtCol = 10;
  static const int _descCol = lineWidth - _qtyCol - _amtCol;

  static String divider([String ch = '-']) => ch * lineWidth;

  static String center(String text, [int width = lineWidth]) {
    final t = text.trim();
    if (t.length >= width) return t.substring(0, width);
    final pad = width - t.length;
    final left = pad ~/ 2;
    return (' ' * left) + t + (' ' * (pad - left));
  }

  static String kv(String label, String value, [int width = lineWidth]) {
    final l = label.trim();
    final v = value.trim();
    final space = width - l.length - v.length;
    if (space < 1) {
      return '$l\n${v.padLeft(width)}';
    }
    return l + (' ' * space) + v;
  }

  static List<String> _itemLines(
    String name,
    String qty,
    String unitPrice,
    String amount,
  ) {
    final qtyStr = qty.padRight(_qtyCol);
    var desc = name.trim();
    if (desc.length > _descCol) {
      desc = '${desc.substring(0, _descCol - 3)}...';
    }
    final descAndQty = (qtyStr + desc).padRight(lineWidth - _amtCol);
    final row =
        descAndQty.substring(0, lineWidth - _amtCol) + amount.padLeft(_amtCol);
    final subLine = '${' ' * _qtyCol}@ $unitPrice';
    return [row, subLine];
  }

  static List<String> buildLines({
    required SaleEntity sale,
    required ShopEntity shop,
  }) {
    return fromContent(ReceiptContent.from(sale: sale, shop: shop));
  }

  static List<String> fromContent(ReceiptContent c) {
    final lines = <String>[
      divider('='),
    ];
    if (c.shopName.isNotEmpty) lines.add(center(c.shopName));
    for (final line in c.letterhead) {
      lines.add(center(line));
    }
    if (c.shopFacts.isNotEmpty) {
      lines.add('');
      for (final row in c.shopFacts) {
        lines.add(kv(row.label, row.value));
      }
    }
    lines.add(divider());
    for (final row in c.identifiers) {
      lines.add(kv(row.label, row.value));
    }
    if (c.customer.isNotEmpty) {
      lines.add(divider());
      lines.add(center('CUSTOMER'));
      for (final row in c.customer) {
        lines.add(kv(row.label, row.value));
      }
    }
    lines.add(divider('='));
    lines.add(
      'QTY'.padRight(_qtyCol) +
          'DESCRIPTION'.padRight(_descCol) +
          'AMOUNT'.padLeft(_amtCol),
    );
    lines.add(divider());
    if (c.items.isEmpty) {
      lines.add(center('(No line items)'));
    } else {
      for (final item in c.items) {
        lines.addAll(_itemLines(item.name, item.qty, item.unitPrice, item.amount));
      }
    }
    lines.add(divider());
    for (final row in c.totals) {
      lines.add(kv(row.label, row.value));
    }
    lines.add(divider('='));
    lines.add(kv('TOTAL', c.grandTotal));
    lines.add(divider());
    for (final row in c.payment) {
      lines.add(kv(row.label, row.value));
    }
    lines.add(divider('='));
    lines.add(center('Thank you'));
    lines.add('');
    return lines;
  }

  // Kept for callers that still format a sale directly.
  static String formatDate(DateTime when) =>
      '${DateFormat('dd/MM/yyyy').format(when)}  '
      '${DateFormat('HH:mm:ss').format(when)}';

  static String amount(num value) => CurrencyFormatter.formatTraDecimal(value);
}
