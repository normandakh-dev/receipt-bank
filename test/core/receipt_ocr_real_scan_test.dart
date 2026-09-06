// Regression tests built from receipts actually scanned on a phone. The
// input is the verbatim ML Kit output stored with each receipt, so these
// cover the crumpled, skewed, badly lit photos that synthetic tests miss.
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_ocr_parser.dart';

import '../support/real_scans.dart';

void main() {
  test('reads the total from a skewed grocery receipt', () {
    // The photo shows SUBTOTAL 130.56, GST 0.42, TOTAL 130.98. Skew put the
    // subtotal and total amounts on one recognised row ("130.56 130.98"),
    // which used to parse as the single amount 56,130.98.
    final result = ReceiptOcrParser.parse(
      RealScans.pcExpressDebit,
      now: DateTime(2026, 9, 5),
    );

    expect(result.totalCents, 13098);
    expect(result.transactionDate, DateTime(2023, 8, 26));
    expect(result.paymentMethod, 'Debit');
  });

  test('reads the total from a crumpled fuel receipt', () {
    // The photo shows Fuel sales 17.82, GST INCLUDED 0.85, TOTAL CAD$ 17.82.
    // The GST registration line ("GST #: R743318321") shared a recognised row
    // with the 17.82, which used to be stored as the tax while 0.85 became
    // the total.
    final result = ReceiptOcrParser.parse(
      RealScans.boundaryTownPantryFuel,
      now: DateTime(2026, 9, 5),
    );

    expect(result.totalCents, 1782);
    expect(result.taxCents, isNot(1782));
    expect(result.paymentMethod, 'Visa');
  });

  test('never merges two amounts sharing one recognised row', () {
    const rawText = '''
NEIGHBOURHOOD MARKET
SUBTOTAL TOTAL
130.56 130.98
DEBIT
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.totalCents, 13098);
  });

  test('ignores an amount sharing a row with a tax registration number', () {
    const rawText = '''
BOUNDARY TOWN PANTRY
GST #: R743318321 \$ 17.82
0.85
TOTAL CAD\$ 17.82
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.taxCents, isNull);
    expect(result.totalCents, 1782);
  });

  test('falls back to the currency-qualified amount for the total', () {
    const rawText = '''
BOUNDARY TOWN PANTRY
PUMP 4
CADS 17.82 499P
0.85
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.totalCents, 1782);
  });
}
