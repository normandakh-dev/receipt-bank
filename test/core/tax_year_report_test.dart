import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/analytics/tax_year_report.dart';

void main() {
  test('builds a twelve-month yearly expense and tax report', () {
    final report = TaxYearReportCalculator.calculate([
      TaxExpenseRecord(
        date: DateTime(2026, 1, 4),
        totalCents: 1000,
        taxCents: 50,
      ),
      TaxExpenseRecord(
        date: DateTime(2026, 1, 20),
        totalCents: 2500,
        taxCents: 125,
      ),
      TaxExpenseRecord(
        date: DateTime(2026, 3, 2),
        totalCents: 5000,
        taxCents: 250,
      ),
      TaxExpenseRecord(
        date: DateTime(2025, 12, 1),
        totalCents: 9999,
        taxCents: 999,
      ),
    ], 2026);

    expect(report.months, hasLength(12));
    expect(report.months[0].totalCents, 3500);
    expect(report.months[0].taxCents, 175);
    expect(report.months[0].receiptCount, 2);
    expect(report.months[1].totalCents, 0);
    expect(report.months[2].totalCents, 5000);
    expect(report.totalCents, 8500);
    expect(report.taxCents, 425);
    expect(report.receiptCount, 3);
  });
}
