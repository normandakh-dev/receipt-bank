import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:receipt_vault_ai/core/analytics/tax_year_report.dart';
import 'package:receipt_vault_ai/core/export/tax_pdf_document_builder.dart';

abstract final class TaxPdfExportService {
  static Future<File> createPdfFile(TaxYearReport report) async {
    final bytes = await TaxPdfDocumentBuilder.build(report);
    final directory = await getTemporaryDirectory();
    final file = File(
      path.join(directory.path, 'receiptvault-tax-report-${report.year}.pdf'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
