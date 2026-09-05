import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:receipt_vault_ai/core/constants/app_constants.dart';
import 'package:receipt_vault_ai/core/storage/receipt_image_storage.dart';
import 'package:receipt_vault_ai/data/local/default_categories.dart';
import 'package:receipt_vault_ai/data/local/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Receipts, ReceiptItems, Categories, Tags, ReceiptTags, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults()
    : super(driftDatabase(name: AppConstants.databaseName));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(receipts, receipts.purpose);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureDefaultCategories();
      await purgeLegacySampleReceipts();
      await repairReceiptImagePaths();
    },
  );

  Future<void> initialize() async {
    await customSelect('SELECT 1').getSingle();
  }

  Stream<List<Category>> watchCategories() {
    return (select(categories)..orderBy([
          (category) => OrderingTerm(
            expression: category.isDefault,
            mode: OrderingMode.desc,
          ),
          (category) => OrderingTerm.asc(category.name),
        ]))
        .watch();
  }

  Future<List<Category>> getCategories() {
    return (select(
      categories,
    )..orderBy([(category) => OrderingTerm.asc(category.name)])).get();
  }

  Stream<List<ReceiptListItem>> watchReceiptList() {
    final query =
        select(receipts).join([
          innerJoin(categories, categories.id.equalsExp(receipts.categoryId)),
        ])..orderBy([
          OrderingTerm.desc(receipts.transactionDate),
          OrderingTerm.desc(receipts.createdAt),
        ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ReceiptListItem(
              receipt: row.readTable(receipts),
              category: row.readTable(categories),
            ),
          )
          .toList(growable: false),
    );
  }

  Stream<ReceiptDetails?> watchReceiptDetails(String receiptId) {
    final query =
        select(receipts).join([
            innerJoin(categories, categories.id.equalsExp(receipts.categoryId)),
            leftOuterJoin(
              receiptItems,
              receiptItems.receiptId.equalsExp(receipts.id),
            ),
          ])
          ..where(receipts.id.equals(receiptId))
          ..orderBy([OrderingTerm.asc(receiptItems.name)]);

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        return null;
      }

      final first = rows.first;
      return ReceiptDetails(
        receipt: first.readTable(receipts),
        category: first.readTable(categories),
        items: rows
            .map((row) => row.readTableOrNull(receiptItems))
            .whereType<ReceiptItem>()
            .toList(growable: false),
      );
    });
  }

  Future<String> createReceipt(ReceiptDraft draft) async {
    final duplicate = await findDuplicateReceipt(
      merchantName: draft.merchantName,
      transactionDate: draft.transactionDate,
      totalCents: draft.totalCents,
      currencyCode: draft.currencyCode,
    );
    if (duplicate != null) {
      throw DuplicateReceiptException(duplicate);
    }

    final now = DateTime.now();
    final receiptId = 'receipt-${now.microsecondsSinceEpoch}';

    await transaction(() async {
      await into(receipts).insert(
        ReceiptsCompanion.insert(
          id: receiptId,
          merchantName: draft.merchantName.trim(),
          transactionDate: draft.transactionDate,
          categoryId: draft.categoryId,
          subtotalCents: Value(draft.subtotalCents),
          taxCents: Value(draft.taxCents),
          tipCents: Value(draft.tipCents),
          totalCents: draft.totalCents,
          currencyCode: Value(draft.currencyCode),
          paymentMethod: Value(_nullIfBlank(draft.paymentMethod)),
          cardLastFour: Value(_nullIfBlank(draft.cardLastFour)),
          notes: Value(_nullIfBlank(draft.notes)),
          purpose: Value(_nullIfBlank(draft.purpose)),
          imagePath: Value(_nullIfBlank(draft.imagePath)),
          rawOcrText: Value(_nullIfBlank(draft.rawOcrText)),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await batch((batch) {
        for (var index = 0; index < draft.items.length; index++) {
          final item = draft.items[index];
          batch.insert(
            receiptItems,
            ReceiptItemsCompanion.insert(
              id: '$receiptId-item-$index',
              receiptId: receiptId,
              name: item.name.trim(),
              quantity: Value(item.quantity),
              unitPriceCents: item.unitPriceCents,
              totalPriceCents: item.totalPriceCents,
            ),
          );
        }
      });
    });

    return receiptId;
  }

  Future<Receipt?> findDuplicateReceipt({
    required String merchantName,
    required DateTime transactionDate,
    required int totalCents,
    String currencyCode = AppConstants.defaultCurrencyCode,
    String? excludingReceiptId,
  }) async {
    final query = select(receipts)
      ..where((receipt) => receipt.transactionDate.equals(transactionDate))
      ..where((receipt) => receipt.totalCents.equals(totalCents))
      ..where((receipt) => receipt.currencyCode.equals(currencyCode));
    final candidates = await query.get();
    final normalizedMerchant = _normalizeMerchantName(merchantName);
    for (final candidate in candidates) {
      if (candidate.id != excludingReceiptId &&
          _normalizeMerchantName(candidate.merchantName) ==
              normalizedMerchant) {
        return candidate;
      }
    }
    return null;
  }

  Future<void> replaceReceipt(String receiptId, ReceiptDraft draft) async {
    final existing = await (select(
      receipts,
    )..where((receipt) => receipt.id.equals(receiptId))).getSingleOrNull();
    if (existing == null) throw StateError('Receipt not found');

    final now = DateTime.now();
    final replacementImagePath = draft.imagePath ?? existing.imagePath;
    await transaction(() async {
      await (update(
        receipts,
      )..where((receipt) => receipt.id.equals(receiptId))).write(
        ReceiptsCompanion(
          merchantName: Value(draft.merchantName.trim()),
          transactionDate: Value(draft.transactionDate),
          categoryId: Value(draft.categoryId),
          subtotalCents: Value(draft.subtotalCents),
          taxCents: Value(draft.taxCents),
          tipCents: Value(draft.tipCents),
          totalCents: Value(draft.totalCents),
          currencyCode: Value(draft.currencyCode),
          paymentMethod: Value(_nullIfBlank(draft.paymentMethod)),
          cardLastFour: Value(_nullIfBlank(draft.cardLastFour)),
          notes: Value(_nullIfBlank(draft.notes)),
          purpose: Value(_nullIfBlank(draft.purpose)),
          imagePath: Value(replacementImagePath),
          rawOcrText: Value(
            _nullIfBlank(draft.rawOcrText) ?? existing.rawOcrText,
          ),
          updatedAt: Value(now),
        ),
      );
      await (delete(
        receiptItems,
      )..where((item) => item.receiptId.equals(receiptId))).go();
      await batch((batch) {
        for (var index = 0; index < draft.items.length; index++) {
          final item = draft.items[index];
          batch.insert(
            receiptItems,
            ReceiptItemsCompanion.insert(
              id: '$receiptId-item-$index',
              receiptId: receiptId,
              name: item.name.trim(),
              quantity: Value(item.quantity),
              unitPriceCents: item.unitPriceCents,
              totalPriceCents: item.totalPriceCents,
            ),
          );
        }
      });
    });

    if (existing.imagePath != replacementImagePath) {
      await ReceiptImageStorage.deleteOwnedImage(existing.imagePath);
    }
  }

  Future<void> setReceiptFavorite(String receiptId, bool isFavorite) async {
    await (update(
      receipts,
    )..where((receipt) => receipt.id.equals(receiptId))).write(
      ReceiptsCompanion(
        isFavorite: Value(isFavorite),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteReceipt(String receiptId) async {
    final receipt = await (select(
      receipts,
    )..where((receipt) => receipt.id.equals(receiptId))).getSingleOrNull();
    await (delete(
      receipts,
    )..where((receipt) => receipt.id.equals(receiptId))).go();
    await ReceiptImageStorage.deleteOwnedImage(receipt?.imagePath);
  }

  /// Deletes the stored photo of every receipt dated before [cutoff] and
  /// clears its image path. The receipt record itself is kept.
  Future<int> removeReceiptImagesBefore(DateTime cutoff) async {
    final stale =
        await (select(receipts)
              ..where((receipt) => receipt.imagePath.isNotNull())
              ..where(
                (receipt) => receipt.transactionDate.isSmallerThanValue(cutoff),
              ))
            .get();
    var removed = 0;
    for (final receipt in stale) {
      await ReceiptImageStorage.deleteOwnedImage(receipt.imagePath);
      await (update(receipts)..where((row) => row.id.equals(receipt.id))).write(
        ReceiptsCompanion(
          imagePath: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
      removed++;
    }
    return removed;
  }

  Future<int> repairReceiptImagePaths() async {
    final withImages = await (select(
      receipts,
    )..where((receipt) => receipt.imagePath.isNotNull())).get();
    var repaired = 0;
    for (final receipt in withImages) {
      final portable = await ReceiptImageStorage.portablePath(
        receipt.imagePath,
      );
      if (portable != null && portable != receipt.imagePath) {
        await (update(receipts)..where((row) => row.id.equals(receipt.id)))
            .write(ReceiptsCompanion(imagePath: Value(portable)));
        repaired++;
      }
    }
    return repaired;
  }

  Future<Map<String, Object?>> exportBackupData() async {
    return {
      'categories': (await select(
        categories,
      ).get()).map((row) => row.toJson()).toList(),
      'receipts': (await select(
        receipts,
      ).get()).map((row) => row.toJson()).toList(),
      'receiptItems': (await select(
        receiptItems,
      ).get()).map((row) => row.toJson()).toList(),
      'tags': (await select(tags).get()).map((row) => row.toJson()).toList(),
      'receiptTags': (await select(
        receiptTags,
      ).get()).map((row) => row.toJson()).toList(),
      'appSettings': (await select(
        appSettings,
      ).get()).map((row) => row.toJson()).toList(),
    };
  }

  Future<void> restoreBackupData(Map<String, dynamic> data) async {
    List<Map<String, dynamic>> rows(String key) => (data[key] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);

    final restoredCategories = rows(
      'categories',
    ).map(Category.fromJson).toList();
    final restoredReceipts = rows('receipts').map(Receipt.fromJson).toList();
    final restoredItems = rows(
      'receiptItems',
    ).map(ReceiptItem.fromJson).toList();
    final restoredTags = rows('tags').map(Tag.fromJson).toList();
    final restoredReceiptTags = rows(
      'receiptTags',
    ).map(ReceiptTag.fromJson).toList();
    final restoredSettings = rows(
      'appSettings',
    ).map(AppSetting.fromJson).toList();

    await transaction(() async {
      await delete(receiptTags).go();
      await delete(receiptItems).go();
      await delete(receipts).go();
      await delete(tags).go();
      await delete(categories).go();
      await delete(appSettings).go();
      await batch((batch) {
        batch.insertAll(categories, restoredCategories);
        batch.insertAll(receipts, restoredReceipts);
        batch.insertAll(receiptItems, restoredItems);
        batch.insertAll(tags, restoredTags);
        batch.insertAll(receiptTags, restoredReceiptTags);
        batch.insertAll(appSettings, restoredSettings);
      });
    });
    await _ensureDefaultCategories();
  }

  Future<int> purgeLegacySampleReceipts() {
    return (delete(
      receipts,
    )..where((receipt) => receipt.id.isIn(_legacySampleReceiptIds))).go();
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((setting) => setting.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<bool> isOnboardingComplete() async {
    return await getSetting(AppSettingKeys.onboardingComplete) == 'true';
  }

  Future<void> setOnboardingComplete(bool isComplete) {
    return setSetting(AppSettingKeys.onboardingComplete, isComplete.toString());
  }

  Future<String> createCategory(String name) async {
    final trimmedName = name.trim();
    await _validateCategoryName(trimmedName);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final categoryId = 'category-custom-$timestamp';
    await into(categories).insert(
      CategoriesCompanion.insert(
        id: categoryId,
        name: trimmedName,
        iconCode: 'label',
        colorValue: const Value(0xFF159455),
      ),
    );
    return categoryId;
  }

  Future<void> updateCategoryName(String categoryId, String name) async {
    final trimmedName = name.trim();
    await _validateCategoryName(trimmedName, exceptId: categoryId);
    final updated =
        await (update(categories)
              ..where((category) => category.id.equals(categoryId)))
            .write(CategoriesCompanion(name: Value(trimmedName)));
    if (updated == 0) {
      throw StateError('Category not found');
    }
  }

  Future<void> _validateCategoryName(String name, {String? exceptId}) async {
    if (name.isEmpty || name.length > 80) {
      throw StateError('Invalid category name');
    }
    final existing = await getCategories();
    final normalized = name.toLowerCase();
    if (existing.any(
      (category) =>
          category.id != exceptId && category.name.toLowerCase() == normalized,
    )) {
      throw StateError('Duplicate category name');
    }
  }

  Future<void> _ensureDefaultCategories() async {
    await batch((batch) {
      for (final category in DefaultCategories.values) {
        batch.insert(
          categories,
          CategoriesCompanion.insert(
            id: category.id,
            name: category.name,
            iconCode: category.iconCode,
            colorValue: Value(category.colorValue),
            isDefault: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }
}

abstract final class AppSettingKeys {
  static const String onboardingComplete = 'onboarding_complete';
}

class ReceiptListItem {
  const ReceiptListItem({required this.receipt, required this.category});

  final Receipt receipt;
  final Category category;
}

class ReceiptDetails {
  const ReceiptDetails({
    required this.receipt,
    required this.category,
    required this.items,
  });

  final Receipt receipt;
  final Category category;
  final List<ReceiptItem> items;
}

class ReceiptDraft {
  const ReceiptDraft({
    required this.merchantName,
    required this.transactionDate,
    required this.categoryId,
    required this.subtotalCents,
    required this.taxCents,
    required this.tipCents,
    required this.totalCents,
    this.currencyCode = AppConstants.defaultCurrencyCode,
    this.paymentMethod,
    this.cardLastFour,
    this.notes,
    this.purpose,
    this.imagePath,
    this.rawOcrText,
    this.items = const [],
  });

  final String merchantName;
  final DateTime transactionDate;
  final String categoryId;
  final int subtotalCents;
  final int taxCents;
  final int tipCents;
  final int totalCents;
  final String currencyCode;
  final String? paymentMethod;
  final String? cardLastFour;
  final String? notes;
  final String? purpose;
  final String? imagePath;
  final String? rawOcrText;
  final List<ReceiptItemDraft> items;
}

class ReceiptItemDraft {
  const ReceiptItemDraft({
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    required this.totalPriceCents,
  });

  final String name;
  final int quantity;
  final int unitPriceCents;
  final int totalPriceCents;
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _normalizeMerchantName(String value) {
  final trimmed = value.trim().toLowerCase();
  final alphanumeric = trimmed.replaceAll(RegExp(r'[^a-z0-9]'), '');
  return alphanumeric.isEmpty
      ? trimmed.replaceAll(RegExp(r'\s+'), ' ')
      : alphanumeric;
}

class DuplicateReceiptException implements Exception {
  const DuplicateReceiptException(this.receipt);

  final Receipt receipt;
}

const Set<String> _legacySampleReceiptIds = {
  'sample-loblaws',
  'sample-save-on-foods',
  'sample-cactus-club',
  'sample-shell',
  'sample-translink',
  'sample-london-drugs',
  'sample-bc-hydro',
  'sample-cineplex',
  'sample-shoppers',
  'sample-air-canada',
  'sample-staples',
  'sample-home-depot',
};
