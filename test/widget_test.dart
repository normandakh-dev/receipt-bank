import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/app/app.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/features/receipts/presentation/receipts_screen.dart';
import 'package:receipt_vault_ai/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('settings exposes iCloud and Google Drive backup', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Save backup to cloud'), findsOneWidget);
    expect(find.textContaining('iCloud Drive'), findsNWidgets(2));
    expect(find.textContaining('Google Drive'), findsNWidgets(2));
    expect(find.text('Restore cloud backup'), findsOneWidget);
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
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Receipts'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Tax'), findsOneWidget);
    expect(find.byTooltip('Scan receipt'), findsOneWidget);

    await tester.tap(find.text('Categories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Looking for category totals?'), findsOneWidget);
    expect(find.byTooltip('Edit Groceries'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Tax'));
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
    expect(find.text('Home'), findsNothing);

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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
