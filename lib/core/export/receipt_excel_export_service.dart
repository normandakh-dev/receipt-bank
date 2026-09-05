import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:receipt_vault_ai/core/export/receipt_excel_workbook_builder.dart';

abstract final class ReceiptExcelExportService {
  static Future<File> createExcelFile(
    Iterable<ReceiptExportRecord> records,
  ) async {
    final now = DateTime.now();
    final bytes = ReceiptExcelWorkbookBuilder.build(records, generatedAt: now);
    final directory = await getTemporaryDirectory();
    final date =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final file = File(
      path.join(directory.path, 'receipt-wallet-all-receipts-$date.xlsx'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
