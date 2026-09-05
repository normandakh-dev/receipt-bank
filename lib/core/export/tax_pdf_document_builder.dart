import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:receipt_vault_ai/core/analytics/tax_year_report.dart';

abstract final class TaxPdfDocumentBuilder {
  static Future<Uint8List> build(
    TaxYearReport report, {
    DateTime? generatedAt,
  }) async {
    final document = pw.Document(
      title: 'ReceiptVault tax report ${report.year}',
      author: 'ReceiptVault AI',
      subject: 'Yearly expenses by month',
      creator: 'ReceiptVault AI',
    );
    final createdAt = generatedAt ?? DateTime.now();
    const brand = PdfColor.fromInt(0xFF185C37);
    const paleBrand = PdfColor.fromInt(0xFFE8F3EC);
    const line = PdfColor.fromInt(0xFFD9E1DC);
    const muted = PdfColor.fromInt(0xFF52615A);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 38),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 22),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RECEIPTVAULT AI',
                    style: pw.TextStyle(
                      color: brand,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Yearly Expense Report',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Text(
                report.year.toString(),
                style: pw.TextStyle(
                  color: brand,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16),
          padding: const pw.EdgeInsets.only(top: 9),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: line)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated ${DateFormat.yMMMd().format(createdAt)}',
                style: const pw.TextStyle(color: muted, fontSize: 8),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(color: muted, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: paleBrand,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: _summaryValue(
                    'TOTAL EXPENSES',
                    _formatCents(report.totalCents),
                    brand,
                    muted,
                  ),
                ),
                pw.Container(width: 1, height: 38, color: line),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: _summaryValue(
                    'TAX RECORDED',
                    _formatCents(report.taxCents),
                    brand,
                    muted,
                  ),
                ),
                pw.Container(width: 1, height: 38, color: line),
                pw.SizedBox(width: 18),
                pw.Expanded(
                  child: _summaryValue(
                    'RECEIPTS',
                    report.receiptCount.toString(),
                    brand,
                    muted,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 26),
          pw.Text(
            'Monthly breakdown',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _monthlyTable(report, brand, paleBrand, line, muted),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(13),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: line),
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Text(
              'For recordkeeping purposes. Verify amounts against the '
              'original receipt photos before filing.',
              style: const pw.TextStyle(color: muted, fontSize: 9),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _summaryValue(
    String label,
    String value,
    PdfColor brand,
    PdfColor muted,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: muted,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.7,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: brand,
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _monthlyTable(
    TaxYearReport report,
    PdfColor brand,
    PdfColor paleBrand,
    PdfColor line,
    PdfColor muted,
  ) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: brand),
        children: [
          _tableCell('MONTH', isHeader: true),
          _tableCell('RECEIPTS', isHeader: true, alignRight: true),
          _tableCell('EXPENSES', isHeader: true, alignRight: true),
          _tableCell('TAX', isHeader: true, alignRight: true),
        ],
      ),
      for (var index = 0; index < report.months.length; index++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isOdd ? paleBrand : PdfColors.white,
            border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.5)),
          ),
          children: [
            _tableCell(
              DateFormat.MMMM().format(
                DateTime(report.year, report.months[index].month),
              ),
            ),
            _tableCell(
              report.months[index].receiptCount.toString(),
              alignRight: true,
              color: muted,
            ),
            _tableCell(
              _formatCents(report.months[index].totalCents),
              alignRight: true,
            ),
            _tableCell(
              _formatCents(report.months[index].taxCents),
              alignRight: true,
              color: muted,
            ),
          ],
        ),
    ];

    return pw.Table(
      border: pw.TableBorder(
        left: pw.BorderSide(color: line),
        right: pw.BorderSide(color: line),
        top: pw.BorderSide(color: line),
        bottom: pw.BorderSide(color: line),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.0),
        1: pw.FlexColumnWidth(1.1),
        2: pw.FlexColumnWidth(1.7),
        3: pw.FlexColumnWidth(1.5),
      },
      children: rows,
    );
  }

  static pw.Widget _tableCell(
    String value, {
    bool isHeader = false,
    bool alignRight = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: pw.Text(
        value,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: isHeader ? PdfColors.white : color,
          fontSize: isHeader ? 8 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _formatCents(int cents) {
    return NumberFormat.currency(
      locale: 'en_CA',
      symbol: r'CA$',
      decimalDigits: 2,
    ).format(cents / 100);
  }
}
