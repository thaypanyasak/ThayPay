import 'package:isar/isar.dart';

import 'models/bank_qr.dart';

class BankQrRepository {
  BankQrRepository(this._isar);

  final Isar _isar;

  /// Watch all bank QR entries, newest first
  Stream<List<BankQr>> watchAll() {
    return _isar.bankQrs
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// Get a single entry by id
  Future<BankQr?> getById(Id id) async {
    return _isar.bankQrs.get(id);
  }

  Future<void> save(BankQr bankQr) async {
    await _isar.writeTxn(() async {
      await _isar.bankQrs.put(bankQr);
    });
  }

  Future<void> delete(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.bankQrs.delete(id);
    });
  }
}
