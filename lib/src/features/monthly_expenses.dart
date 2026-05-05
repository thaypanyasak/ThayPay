import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/expense_repository.dart';
import '../data/models/expense.dart';
import '../data/providers.dart';

final currentMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final expenseRepositoryAsyncProvider =
    Provider<AsyncValue<ExpenseRepository>>((ref) {
  final isarAsync = ref.watch(isarProvider);
  return isarAsync.whenData((isar) => ExpenseRepository(isar));
});

final monthlyExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final month = ref.watch(currentMonthProvider);
  final repoAsync = ref.watch(expenseRepositoryAsyncProvider);

  return repoAsync.when(
    data: (repo) => repo.watchExpensesInMonth(month),
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final monthlySpentTotalProvider = Provider<int>((ref) {
  final expensesAsync = ref.watch(monthlyExpensesProvider);
  return expensesAsync.maybeWhen(
    data: (items) {
      // If user stores expenses as negative, spent is -sum of negatives.
      // Here we treat all negative amounts as spending.
      final spent = items
          .where((e) => e.amountVnd < 0)
          .fold<int>(0, (acc, e) => acc + e.amountVnd);
      return spent.abs();
    },
    orElse: () => 0,
  );
});

/// Provider that watches ALL expenses in a broad range
/// (2 years back to 3 months forward) for the scrollable calendar.
final calendarRangeExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final repoAsync = ref.watch(expenseRepositoryAsyncProvider);
  final now = DateTime.now();
  final start = DateTime(now.year - 2, now.month);
  final end = DateTime(now.year, now.month + 4); // current + 3 months

  return repoAsync.when(
    data: (repo) => repo.watchExpensesInRange(start, end),
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
