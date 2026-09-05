import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/classification/receipt_purpose_classifier.dart';

void main() {
  test('recognizes a grocery receipt from its merchant', () {
    final result = ReceiptPurposeClassifier.classify(
      merchantName: 'Loblaws City Market',
    );

    expect(result.categoryId, 'category-groceries');
    expect(result.purpose, 'Groceries and household essentials');
    expect(result.confidence, greaterThan(0.8));
  });

  test('uses line items when the merchant is unknown', () {
    final result = ReceiptPurposeClassifier.classify(
      merchantName: 'Corner Shop',
      itemNames: const ['Prescription medicine'],
    );

    expect(result.categoryId, 'category-health');
    expect(result.purpose, 'Health and personal care');
  });

  test('falls back safely when there is no strong match', () {
    final result = ReceiptPurposeClassifier.classify(
      merchantName: 'Unknown Vendor',
    );

    expect(result.categoryId, 'category-other');
    expect(result.purpose, 'General purchase');
  });

  test('recognizes a Vancouver restaurant alias with a specific purpose', () {
    final result = ReceiptPurposeClassifier.classify(
      merchantName: 'BREKA BAKERY & CAFE #4',
    );

    expect(result.categoryId, 'category-restaurants');
    expect(result.purpose, 'Cafe, bakery, and prepared food');
    expect(result.confidence, greaterThan(0.9));
  });
}
