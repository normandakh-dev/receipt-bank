import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/formatters/money_formatter.dart';

void main() {
  test('formats integer cents as Canadian currency', () {
    expect(MoneyFormatter.formatCents(124550), r'$1,245.50');
  });
}
