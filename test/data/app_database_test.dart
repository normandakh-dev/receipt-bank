import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/local/default_categories.dart';

import '../support/fake_path_provider.dart';

void main() {
  late AppDatabase database;
  late Directory root;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('receipt-db-test');
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: root.path,
      temporaryPath: root.path,
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('creates all default categories', () async {
    await database.initialize();

    final categories = await database.select(database.categories).get();

    expect(categories, hasLength(DefaultCategories.values.length));
    expect(
      categories.map((category) => category.name),
      containsAll(['Groceries', 'Restaurants', 'Business', 'Other']),
    );
    expect(categories.every((category) => category.isDefault), isTrue);
  });

  test('renames categories and rejects duplicate names', () async {
    await database.initialize();

    await database.updateCategoryName('category-groceries', 'Food at home');
    final categories = await database.getCategories();

    expect(
      categories.singleWhere((item) => item.id == 'category-groceries').name,
      'Food at home',
    );
    await expectLater(
      database.updateCategoryName('category-groceries', 'Restaurants'),
      throwsA(isA<StateError>()),
    );
  });

  test('purges legacy examples without deleting a user receipt', () async {
    await database.initialize();
    await database
        .into(database.receipts)
        .insert(
          ReceiptsCompanion.insert(
            id: 'sample-loblaws',
            merchantName: 'Legacy example',
            transactionDate: DateTime(2026, 7, 1),
            categoryId: 'category-groceries',
            totalCents: 1000,
          ),
        );
    await database
        .into(database.receipts)
        .insert(
          ReceiptsCompanion.insert(
            id: 'user-receipt',
            merchantName: 'Real purchase',
            transactionDate: DateTime(2026, 7, 2),
            categoryId: 'category-groceries',
            totalCents: 2000,
          ),
        );

    final removed = await database.purgeLegacySampleReceipts();
    final receipts = await database.select(database.receipts).get();

    expect(removed, 1);
    expect(receipts.map((receipt) => receipt.id), ['user-receipt']);
  });

  test('creates a categorized receipt with purpose and line items', () async {
    await database.initialize();

    final receiptId = await database.createReceipt(
      ReceiptDraft(
        merchantName: 'Neighbourhood Market',
        transactionDate: DateTime(2026, 7, 28),
        categoryId: 'category-groceries',
        subtotalCents: 1000,
        taxCents: 50,
        tipCents: 0,
        totalCents: 1050,
        purpose: 'Groceries and household essentials',
        imagePath: '/private/receipt-images/market.jpg',
        rawOcrText: 'NEIGHBOURHOOD MARKET\nTOTAL 10.50',
        items: const [
          ReceiptItemDraft(
            name: 'Fresh produce',
            quantity: 1,
            unitPriceCents: 1000,
            totalPriceCents: 1000,
          ),
        ],
      ),
    );

    final detail = await database
        .watchReceiptDetails(receiptId)
        .firstWhere((value) => value != null);
    final list = await database.watchReceiptList().first;

    expect(detail?.receipt.purpose, 'Groceries and household essentials');
    expect(detail?.receipt.imagePath, '/private/receipt-images/market.jpg');
    expect(detail?.receipt.rawOcrText, contains('TOTAL 10.50'));
    expect(detail?.category.name, 'Groceries');
    expect(detail?.items.single.name, 'Fresh produce');
    expect(list.single.receipt.totalCents, 1050);
  });

  test('removes photos older than a cutoff but keeps the receipts', () async {
    await database.initialize();
    final images = await Directory(
      path.join(root.path, 'receipt_images'),
    ).create();
    final oldPhoto = await File(
      path.join(images.path, 'old.jpg'),
    ).writeAsBytes([1, 2, 3]);
    final newPhoto = await File(
      path.join(images.path, 'new.jpg'),
    ).writeAsBytes([4, 5, 6]);
    final oldId = await database.createReceipt(
      ReceiptDraft(
        merchantName: 'Old Shop',
        transactionDate: DateTime(2024, 1, 15),
        categoryId: 'category-other',
        subtotalCents: 100,
        taxCents: 0,
        tipCents: 0,
        totalCents: 100,
        imagePath: 'receipt_images/old.jpg',
      ),
    );
    final newId = await database.createReceipt(
      ReceiptDraft(
        merchantName: 'New Shop',
        transactionDate: DateTime(2026, 8, 1),
        categoryId: 'category-other',
        subtotalCents: 200,
        taxCents: 0,
        tipCents: 0,
        totalCents: 200,
        imagePath: 'receipt_images/new.jpg',
      ),
    );

    final removed = await database.removeReceiptImagesBefore(
      DateTime(2025, 9, 5),
    );

    final rows = {
      for (final row in await database.select(database.receipts).get())
        row.id: row,
    };
    expect(removed, 1);
    expect(rows[oldId]?.imagePath, isNull);
    expect(rows[oldId]?.merchantName, 'Old Shop');
    expect(rows[newId]?.imagePath, 'receipt_images/new.jpg');
    expect(await oldPhoto.exists(), isFalse);
    expect(await newPhoto.exists(), isTrue);
  });

  test('detects duplicate receipts and can replace the existing row', () async {
    await database.initialize();
    final original = ReceiptDraft(
      merchantName: 'City of Vancouver',
      transactionDate: DateTime(2024, 12, 24),
      categoryId: 'category-business',
      subtotalCents: 5000,
      taxCents: 0,
      tipCents: 0,
      totalCents: 5000,
      notes: 'Original',
    );
    final receiptId = await database.createReceipt(original);

    final duplicate = await database.findDuplicateReceipt(
      merchantName: ' CITY OF VANCOUVER ',
      transactionDate: DateTime(2024, 12, 24),
      totalCents: 5000,
    );

    expect(duplicate?.id, receiptId);
    await expectLater(
      database.createReceipt(original),
      throwsA(isA<DuplicateReceiptException>()),
    );

    await database.replaceReceipt(
      receiptId,
      ReceiptDraft(
        merchantName: 'City of Vancouver',
        transactionDate: DateTime(2024, 12, 24),
        categoryId: 'category-business',
        subtotalCents: 5000,
        taxCents: 0,
        tipCents: 0,
        totalCents: 5000,
        notes: 'Replacement',
      ),
    );
    final receipts = await database.select(database.receipts).get();

    expect(receipts, hasLength(1));
    expect(receipts.single.id, receiptId);
    expect(receipts.single.notes, 'Replacement');
  });
}
