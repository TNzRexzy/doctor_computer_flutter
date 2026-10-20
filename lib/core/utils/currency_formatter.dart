import 'package:intl/intl.dart';

/// Formats numbers to Indonesian Rupiah representation.
class CurrencyFormatter {
  CurrencyFormatter._();

  static String formatRupiah(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  static String formatRupiahCompact(double amount) {
    if (amount >= 1000000) {
      double millions = amount / 1000000;
      String str = millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1);
      str = str.replaceAll('.', ',');
      return 'Rp ${str}jt';
    } else if (amount >= 1000) {
      double thousands = amount / 1000;
      String str = thousands.toStringAsFixed(thousands.truncateToDouble() == thousands ? 0 : 1);
      str = str.replaceAll('.', ',');
      return 'Rp ${str}rb';
    } else {
      return formatRupiah(amount);
    }
  }
}

/// Formats amount into Indonesian Rupiah currency format.
String formatRupiah(double amount) => CurrencyFormatter.formatRupiah(amount);

/// Formats amount into compact Indonesian Rupiah currency format.
String formatRupiahCompact(double amount) => CurrencyFormatter.formatRupiahCompact(amount);
