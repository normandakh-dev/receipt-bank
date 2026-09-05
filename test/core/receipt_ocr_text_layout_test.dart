import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_ocr_text_layout.dart';

void main() {
  test('reassembles text blocks into visual receipt rows', () {
    const fragments = [
      ReceiptOcrTextFragment(
        text: 'SUBTOTAL',
        left: 20,
        top: 100,
        width: 90,
        height: 20,
      ),
      ReceiptOcrTextFragment(
        text: 'TOTAL',
        left: 20,
        top: 130,
        width: 65,
        height: 20,
      ),
      ReceiptOcrTextFragment(
        text: '8.03',
        left: 230,
        top: 101,
        width: 45,
        height: 20,
      ),
      ReceiptOcrTextFragment(
        text: '8.03',
        left: 230,
        top: 131,
        width: 45,
        height: 20,
      ),
    ];

    expect(
      ReceiptOcrTextLayout.arrange(fragments),
      'SUBTOTAL 8.03\nTOTAL 8.03',
    );
  });

  test('uses the recognizer text when no line geometry is available', () {
    expect(
      ReceiptOcrTextLayout.arrange(const [], fallback: 'TOTAL 8.03'),
      'TOTAL 8.03',
    );
  });
}
