import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/bank_qr.dart';
import 'models/expense.dart';

class IsarService {
  const IsarService();

  Future<Isar> open() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [ExpenseSchema, BankQrSchema],
      directory: dir.path,
    );
  }
}
