import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_ocr_parser.dart';

void main() {
  test('extracts common Canadian receipt fields and line items', () {
    const rawText = '''
LOBLAWS CITY MARKET
123 ROBSON ST
VANCOUVER BC
2026-07-26 14:32
MILK 4.99
BREAD 3.50
SUBTOTAL 8.49
GST 0.42
TOTAL \$8.91
VISA **** 4242
THANK YOU
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.merchantName, 'Loblaws City Market');
    expect(result.transactionDate, DateTime(2026, 7, 26));
    expect(result.subtotalCents, 849);
    expect(result.taxCents, 42);
    expect(result.totalCents, 891);
    expect(result.paymentMethod, 'Visa');
    expect(result.cardLastFour, '4242');
    expect(
      result.items.map((item) => item.name),
      containsAll(['Milk', 'Bread']),
    );
  });

  test('adds separate GST and PST amounts', () {
    const rawText = '''
CANADIAN TIRE
07/24/2026
LIGHT BULB 10.00
SUBTOTAL 10.00
GST 0.50
PST 0.70
GRAND TOTAL 11.20
DEBIT
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.merchantName, 'Canadian Tire');
    expect(result.transactionDate, DateTime(2026, 7, 24));
    expect(result.taxCents, 120);
    expect(result.totalCents, 1120);
    expect(result.paymentMethod, 'Debit');
  });

  test('falls back to the largest trailing amount when total is unlabeled', () {
    const rawText = '''
CORNER CAFE
Jul 20, 2026
COFFEE 4.25
MUFFIN 3.75
8.00
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.merchantName, 'Corner Cafe');
    expect(result.transactionDate, DateTime(2026, 7, 20));
    expect(result.totalCents, 800);
  });

  test('normalizes Vancouver merchant aliases and OCR amount mistakes', () {
    const rawText = '''
SAVEONFOODS #2219
2949 MAIN ST
VANCOUVER BC
2026-07-30
T0TAL \$12.9I
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.merchantName, 'Save-On-Foods');
    expect(result.totalCents, 1291);
  });

  test('finds a total printed on the line after its label', () {
    const rawText = '''
NEIGHBOURHOOD MARKET
SUBTOTAL 24.00
GST 1.20
AMOUNT DUE
\$25.20
VISA **** 7788
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.totalCents, 2520);
  });

  test('finds a total when OCR separates dollars and cents', () {
    const rawText = '''
PARKSIDE CAFE
LATTE 5.25
T0TAL 5 25
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.totalCents, 525);
  });

  test('finds an amount printed before the total label', () {
    const rawText = '''
CITY PHARMACY
SUBTOTAL 18.50
GST 0.93
\$19.43 GRAND TOTAL
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.totalCents, 1943);
  });

  test('calculates total from subtotal and taxes when total is unreadable', () {
    const rawText = '''
HARDWARE SHOP
SUBTOTAL 40.00
GST 2.00
PST 2.80
CASH 100.00
CHANGE 55.20
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.totalCents, 4480);
  });

  test('finds amounts when ML Kit separates receipt columns', () {
    const rawText = '''
INDEPENDENT
COGY LRG FR EGGS MRJ
SUBTOTAL
TOTAL
Trans. Type: PURCHASE
Account: MASTERCARD
Card Type: CREDIT
Card Number
Date
Time
Ref.
Auth
MASTERCARD
8.03
8. 03
8. O3
CAD\$
8.03
************0525
Win a \$1, 000 PC gift card
You just unlocked 5, 000 points
That's \$5 in free value
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.subtotalCents, 803);
    expect(result.totalCents, 803);
  });

  test('prefers the repeated total in a separated amount column', () {
    const rawText = '''
NEIGHBOURHOOD MARKET
ITEM
SUBTOTAL
GST
TOTAL
Trans. Type: PURCHASE
Account: MASTERCARD
Card Number
Date
Time
5.00
10.00
0.50
10.50
10.50
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.totalCents, 1050);
  });

  test('parses a month-name date without a space after the comma', () {
    const rawText = '''
CITY OF VANCOUVER
Purchase
Dec 24,2024
TOTAL \$50.00
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.transactionDate, DateTime(2024, 12, 24));
  });

  test('leaves the date unset when the receipt has no valid date', () {
    const rawText = '''
CORNER STORE
COFFEE 4.50
TOTAL 4.50
''';

    final result = ReceiptOcrParser.parse(rawText);

    expect(result.transactionDate, isNull);
  });
}
