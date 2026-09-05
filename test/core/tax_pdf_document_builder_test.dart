import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/analytics/tax_year_report.dart';
import 'package:receipt_vault_ai/core/export/tax_pdf_document_builder.dart';

void main() {
  test('creates a valid PDF containing a yearly tax report', () async {
    final report = TaxYearReportCalculator.calculate([
      TaxExpenseRecord(
        date: DateTime(2026, 1, 12),
        totalCents: 12845,
        taxCents: 612,
      ),
      TaxExpenseRecord(
        date: DateTime(2026, 7, 20),
        totalCents: 7820,
        taxCents: 371,
      ),
    ], 2026);

    final bytes = await TaxPdfDocumentBuilder.build(
      report,
      generatedAt: DateTime(2026, 7, 29),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(
      String.fromCharCodes(bytes.skip(bytes.length - 6)),
      contains('%%EOF'),
    );
  });
}
