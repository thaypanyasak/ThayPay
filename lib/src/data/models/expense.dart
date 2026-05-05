import 'package:isar/isar.dart';

part 'expense.g.dart';

@collection
class Expense {
  Expense();

  Id id = Isar.autoIncrement;

  /// Signed amount in VND.
  /// - Expense: negative (e.g. -30000)
  /// - Income: positive
  int amountVnd = 0;

  /// Emoji category for quick visual grouping (e.g. 🍜 🥤 🚕).
  String? emoji;

  String description = '';

  /// Local file path to the stored/compressed image.
  String? imagePath;

  @Index()
  DateTime createdAt = DateTime.now();
}
