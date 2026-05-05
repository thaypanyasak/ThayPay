import 'package:isar/isar.dart';

import 'models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._isar);

  final Isar _isar;

  Stream<List<Expense>> watchExpensesInMonth(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);

    return _isar.expenses
        .filter()
        .createdAtBetween(start, end)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// Watch all expenses across a date range (for the scrollable calendar).
  Stream<List<Expense>> watchExpensesInRange(DateTime start, DateTime end) {
    return _isar.expenses
        .filter()
        .createdAtBetween(start, end)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<void> addExpense(Expense expense) async {
    await _isar.writeTxn(() async {
      await _isar.expenses.put(expense);
    });
  }
}
