import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(databaseProvider).watchCategories();
});

final receiptListProvider = StreamProvider<List<ReceiptListItem>>((ref) {
  return ref.watch(databaseProvider).watchReceiptList();
});

final receiptDetailsProvider = StreamProvider.autoDispose
    .family<ReceiptDetails?, String>((ref, id) {
      return ref.watch(databaseProvider).watchReceiptDetails(id);
    });
