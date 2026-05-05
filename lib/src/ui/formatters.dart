import 'package:intl/intl.dart';

final vndFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

/// Formats a number string with VND comma separators while typing.
/// E.g., "30000" -> "30,000", "-1500000" -> "-1,500,000"
String formatVndComma(String raw) {
  // Remove all non-digit characters except leading minus
  final isNegative = raw.startsWith('-');
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return isNegative ? '-' : '';

  // Parse to int and format with commas
  final number = int.parse(digits);
  final formatted = NumberFormat('#,###').format(number);
  return isNegative ? '-$formatted' : formatted;
}

int? parseVndInput(String raw) {
  final cleaned = raw
      .trim()
      .toLowerCase()
      .replaceAll('vnđ', '')
      .replaceAll('vnd', '')
      .replaceAll('₫', '')
      .replaceAll('.', '')
      .replaceAll(',', '')
      .replaceAll(' ', '');

  if (cleaned.isEmpty) return null;
  return int.tryParse(cleaned);
}
