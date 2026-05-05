import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'bank_qr_repository.dart';
import 'expense_repository.dart';
import 'isar_service.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  const service = IsarService();
  final isar = await service.open();
  ref.onDispose(() {
    isar.close();
  });
  return isar;
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final isarAsync = ref.watch(isarProvider);
  return isarAsync.when(
    data: (isar) => ExpenseRepository(isar),
    loading: () => throw StateError('Isar not ready'),
    error: (e, _) => throw StateError('Isar failed: $e'),
  );
});

final bankQrRepositoryProvider = Provider<BankQrRepository>((ref) {
  final isarAsync = ref.watch(isarProvider);
  return isarAsync.when(
    data: (isar) => BankQrRepository(isar),
    loading: () => throw StateError('Isar not ready'),
    error: (e, _) => throw StateError('Isar failed: $e'),
  );
});
