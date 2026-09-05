import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:receipt_vault_ai/app/app.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/features/receipts/presentation/receipts_screen.dart';
import 'package:receipt_vault_ai/features/settings/presentation/settings_screen.dart';

import 'support/fake_path_provider.dart';

void main() {
  testWidgets('settings exposes backup and photo storage controls', (
    tester,
  ) async {
    // Real file I/O never completes inside the fake-async test zone, so the
    // temp directory is created synchronously and the screen is pumped
    // under runAsync while it measures photo storage.
    final root = Directory.systemTemp.createTempSync('receipt-widget-test');
    addTearDown(() => root.deleteSync(recursive: true));
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: root.path,
      temporaryPath: root.path,
    );
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.initialize();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('Save backup to cloud'), findsOneWidget);
    expect(find.textContaining('iCloud Drive'), findsNWidgets(2));
    expect(find.textContaining('Google Drive'), findsNWidgets(2));
    expect(find.text('Restore cloud backup'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Delete photos older than one year'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Receipt photos'), findsOneWidget);
    expect(find.text('0 photos · 0 B'), findsOneWidget);
  });

  testWidgets('main navigation exposes all five destinations', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.initialize();
    await database.setOnboardingComplete(true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const ReceiptVaultApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('RECEIPTVAULT AI'), findsNothing);
    expect(find.text('Receipt Wallet'), findsNothing);
    expect(find.textContaining('Good '), findsNothing);
    // The paper-ledger navigation pill is icon-only; destinations are
    // exposed through tooltips and semantics labels.
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('Receipts'), findsOneWidget);
    expect(find.byTooltip('Reports'), findsOneWidget);
    expect(find.byTooltip('Tax'), findsOneWidget);
    expect(find.byTooltip('Scan receipt'), findsOneWidget);
    expect(find.text('LATEST'), findsOneWidget);
    expect(find.textContaining('TOP CATEGORIES'), findsOneWidget);

    // Categories are managed from Settings now.
    await tester.tap(find.byTooltip('Settings and backup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Looking for category totals?'), findsOneWidget);
    expect(find.byTooltip('Edit Groceries'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('Tax'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Yearly expenses'), findsOneWidget);
    expect(find.text('Month by month'), findsOneWidget);
    expect(find.text('Send 2026 tax PDF'), findsOneWidget);

    await tester.tap(find.byTooltip('Scan receipt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Scan a receipt'), findsOneWidget);
    expect(find.textContaining('STAGE 3'), findsNothing);
    expect(find.textContaining('ON-DEVICE OCR'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Enter manually instead'),
      250,
      scrollable: find.byType(Scrollable).hitTestable(),
    );
    expect(find.text('Take receipt photo'), findsOneWidget);
    expect(find.text('Choose from photos'), findsOneWidget);

    await tester.tap(find.text('Enter manually instead'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Add receipt'), findsOneWidget);
    expect(find.byTooltip('Home'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('date range opens only receipts from the selected month', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.initialize();
    await database.createReceipt(
      ReceiptDraft(
        merchantName: 'July Market',
        transactionDate: DateTime(2026, 7, 15),
        categoryId: 'category-groceries',
        subtotalCents: 1000,
        taxCents: 0,
        tipCents: 0,
        totalCents: 1000,
      ),
    );
    await database.createReceipt(
      ReceiptDraft(
        merchantName: 'June Market',
        transactionDate: DateTime(2026, 6, 15),
        categoryId: 'category-groceries',
        subtotalCents: 2000,
        taxCents: 0,
        tipCents: 0,
        totalCents: 2000,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: ReceiptsScreen(
            initialStart: DateTime(2026, 7),
            initialEndExclusive: DateTime(2026, 8),
            periodLabel: 'July 2026',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('July Market'), findsOneWidget);
    expect(find.text('June Market'), findsNothing);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('JUL 15 · GROCERIES'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
