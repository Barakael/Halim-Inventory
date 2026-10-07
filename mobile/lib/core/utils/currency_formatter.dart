import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat('#,###', 'en');
  static final _traDecimals = NumberFormat('#,##0.00', 'en_US');

  static String format(num amount) {
    return 'TZS ${_formatter.format(amount)}';
  }

  /// Receipt amounts (no currency prefix), e.g. `100,000.00`
  static String formatTraDecimal(num amount) {
    return _traDecimals.format(amount);
  }

  static String formatCompact(num amount) {
    if (amount >= 1000000) {
      return 'TZS ${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return 'TZS ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }
}
