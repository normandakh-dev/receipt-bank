import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/export/receipt_excel_workbook_builder.dart';

void main() {
  test('creates an organized Excel workbook for every year and month', () {
    final bytes = ReceiptExcelWorkbookBuilder.build([
      ReceiptExportRecord(
        id: 'receipt-2026-july',
        date: DateTime(2026, 7, 20),
        merchant: 'Save-On-Foods & Pharmacy',
        category: 'Groceries',
        purpose: 'Groceries and household essentials',
        subtotalCents: 12000,
        taxCents: 600,
        tipCents: 0,
        totalCents: 12600,
        currencyCode: 'CAD',
        paymentMethod: 'Visa',
        cardLastFour: '4242',
        notes: 'Weekly shop',
        hasPhoto: true,
      ),
      ReceiptExportRecord(
        id: 'receipt-2026-january',
        date: DateTime(2026, 1, 5),
        merchant: 'Breka Bakery & Cafe',
        category: 'Restaurants',
        purpose: 'Cafe, bakery, and prepared food',
        subtotalCents: 1000,
        taxCents: 50,
        tipCents: 150,
        totalCents: 1200,
        currencyCode: 'CAD',
        hasPhoto: false,
      ),
      ReceiptExportRecord(
        id: 'receipt-2025-december',
        date: DateTime(2025, 12, 15),
        merchant: 'London Drugs',
        category: 'Health',
        subtotalCents: 2000,
        taxCents: 240,
        tipCents: 0,
        totalCents: 2240,
        currencyCode: 'CAD',
        hasPhoto: true,
      ),
    ], generatedAt: DateTime(2026, 7, 31, 18, 30));

    expect(bytes.take(2), [0x50, 0x4B]);
    final archive = ZipDecoder().decodeBytes(bytes);
    final paths = archive.files.map((file) => file.name).toSet();
    expect(
      paths,
      containsAll([
        '[Content_Types].xml',
        'xl/workbook.xml',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/sheet2.xml',
        'xl/worksheets/sheet3.xml',
        'xl/worksheets/sheet4.xml',
      ]),
    );

    String read(String path) =>
        utf8.decode(archive.findFile(path)!.content, allowMalformed: false);

    final workbook = read('xl/workbook.xml');
    expect(workbook, contains('name="Summary"'));
    expect(workbook, contains('name="All Receipts"'));
    expect(workbook, contains('name="2026"'));
    expect(workbook, contains('name="2025"'));

    final summary = read('xl/worksheets/sheet1.xml');
    expect(summary, contains('Receipt Wallet — Receipt Summary'));
    expect(summary, contains('COUNTIF'));
    expect(summary, contains('SUMIF'));

    final allReceipts = read('xl/worksheets/sheet2.xml');
    expect(allReceipts, contains('All Saved Receipts'));
    expect(allReceipts, contains('Save-On-Foods &amp; Pharmacy'));
    expect(allReceipts, contains('receipt-2025-december'));
    expect(allReceipts, contains('autoFilter'));

    final year2026 = read('xl/worksheets/sheet3.xml');
    expect(year2026, contains('2026 Receipts — Organized by Month'));
    expect(year2026, contains('January'));
    expect(year2026, contains('July'));
    expect(year2026, contains('Month total'));
    expect(year2026, isNot(contains('#REF!')));
  });
}
