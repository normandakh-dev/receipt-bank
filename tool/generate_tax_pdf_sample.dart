import 'dart:io';

import 'package:receipt_vault_ai/core/analytics/tax_year_report.dart';
import 'package:receipt_vault_ai/core/export/tax_pdf_document_builder.dart';

Future<void> main() async {
  final report = TaxYearReportCalculator.calculate([
    for (var month = 1; month <= 12; month++) ...[
      TaxExpenseRecord(
        date: DateTime(2026, month, 5),
        totalCents: 8500 + (month * 1375),
        taxCents: 410 + (month * 63),
      ),
      if (month.isEven)
        TaxExpenseRecord(
          date: DateTime(2026, month, 18),
          totalCents: 4200 + (month * 525),
          taxCents: 201 + (month * 25),
        ),
    ],
  ], 2026);
  final bytes = await TaxPdfDocumentBuilder.build(
    report,
    generatedAt: DateTime(2026, 7, 29),
  );
  final directory = Directory('output/pdf');
  await directory.create(recursive: true);
  final file = File('${directory.path}/receiptvault-tax-report-sample.pdf');
  await file.writeAsBytes(bytes, flush: true);
  stdout.writeln(file.absolute.path);
}
