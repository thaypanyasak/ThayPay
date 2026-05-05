import 'package:isar/isar.dart';

part 'bank_qr.g.dart';

@collection
class BankQr {
  BankQr();

  Id id = Isar.autoIncrement;

  /// Bank display name (e.g. "Vietcombank", "MB Bank")
  String title = '';

  /// Local file path to the bank logo image
  String? logoPath;

  /// Local file path to the QR code image
  String? qrImagePath;

  @Index()
  DateTime createdAt = DateTime.now();
}
