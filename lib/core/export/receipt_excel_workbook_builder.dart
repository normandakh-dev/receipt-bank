import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';

class ReceiptExportRecord {
  const ReceiptExportRecord({
    required this.id,
    required this.date,
    required this.merchant,
    required this.category,
    required this.subtotalCents,
    required this.taxCents,
    required this.tipCents,
    required this.totalCents,
    required this.currencyCode,
    required this.hasPhoto,
    this.purpose,
    this.paymentMethod,
    this.cardLastFour,
    this.notes,
  });

  factory ReceiptExportRecord.fromListItem(ReceiptListItem item) {
    final receipt = item.receipt;
    return ReceiptExportRecord(
      id: receipt.id,
      date: receipt.transactionDate,
      merchant: receipt.merchantName,
      category: item.category.name,
      purpose: receipt.purpose,
      subtotalCents: receipt.subtotalCents,
      taxCents: receipt.taxCents,
      tipCents: receipt.tipCents,
      totalCents: receipt.totalCents,
      currencyCode: receipt.currencyCode,
      paymentMethod: receipt.paymentMethod,
      cardLastFour: receipt.cardLastFour,
      notes: receipt.notes,
      hasPhoto: receipt.imagePath?.trim().isNotEmpty ?? false,
    );
  }

  final String id;
  final DateTime date;
  final String merchant;
  final String category;
  final String? purpose;
  final int subtotalCents;
  final int taxCents;
  final int tipCents;
  final int totalCents;
  final String currencyCode;
  final String? paymentMethod;
  final String? cardLastFour;
  final String? notes;
  final bool hasPhoto;
}

abstract final class ReceiptExcelWorkbookBuilder {
  static Uint8List build(
    Iterable<ReceiptExportRecord> source, {
    DateTime? generatedAt,
  }) {
    final createdAt = generatedAt ?? DateTime.now();
    final records = source.toList()
      ..sort((a, b) {
        final dateComparison = b.date.compareTo(a.date);
        return dateComparison != 0
            ? dateComparison
            : a.merchant.compareTo(b.merchant);
      });
    final years = records.map((record) => record.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final sheets = <_WorkbookSheet>[
      _WorkbookSheet(
        name: 'Summary',
        xml: _summarySheet(records, years, createdAt),
      ),
      _WorkbookSheet(
        name: 'All Receipts',
        xml: _allReceiptsSheet(records, createdAt),
      ),
      for (final year in years)
        _WorkbookSheet(
          name: year.toString(),
          xml: _yearSheet(
            year,
            records.where((record) => record.date.year == year).toList(),
            records.length,
            createdAt,
          ),
        ),
    ];

    final archive = Archive();
    void add(String path, String content) {
      archive.addFile(ArchiveFile.string(path, content));
    }

    add('[Content_Types].xml', _contentTypes(sheets.length));
    add('_rels/.rels', _rootRelationships);
    add('docProps/core.xml', _coreProperties(createdAt));
    add('docProps/app.xml', _appProperties(sheets));
    add('xl/workbook.xml', _workbook(sheets));
    add('xl/_rels/workbook.xml.rels', _workbookRelationships(sheets.length));
    add('xl/styles.xml', _styles);
    for (var index = 0; index < sheets.length; index++) {
      add('xl/worksheets/sheet${index + 1}.xml', sheets[index].xml);
    }

    return ZipEncoder().encodeBytes(archive);
  }

  static String _summarySheet(
    List<ReceiptExportRecord> records,
    List<int> years,
    DateTime generatedAt,
  ) {
    final lastDataRow = records.isEmpty ? 5 : records.length + 4;
    final totalCents = records.fold<int>(
      0,
      (sum, record) => sum + record.totalCents,
    );
    final rows = <String>[
      _row(1, [_textCell('A1', 'Receipt Wallet — Receipt Summary', 1)]),
      _row(2, [
        _textCell(
          'A2',
          'Generated ${DateFormat.yMMMd().add_jm().format(generatedAt)}',
          9,
        ),
      ]),
      _row(4, [
        _textCell('A4', 'All saved receipts', 3),
        _formulaCell(
          'B4',
          "COUNTA('All Receipts'!\u0024A\u00245:\u0024A\u0024$lastDataRow)",
          records.length,
          6,
        ),
        _textCell('D4', 'All-time spending', 3),
        _formulaCell(
          'E4',
          "SUM('All Receipts'!\u0024K\u00245:\u0024K\u0024$lastDataRow)",
          totalCents / 100,
          7,
        ),
      ]),
      _row(6, [
        _textCell('A6', 'Year', 2),
        _textCell('B6', 'Receipts', 2),
        _textCell('C6', 'Subtotal', 2),
        _textCell('D6', 'Tax', 2),
        _textCell('E6', 'Tip', 2),
        _textCell('F6', 'Total', 2),
      ]),
    ];

    if (years.isEmpty) {
      rows.add(_row(7, [_textCell('A7', 'No saved receipts yet.', 8)]));
    } else {
      for (var index = 0; index < years.length; index++) {
        final year = years[index];
        final rowNumber = 7 + index;
        final yearRecords = records
            .where((record) => record.date.year == year)
            .toList();
        final subtotal = _sum(yearRecords, (record) => record.subtotalCents);
        final tax = _sum(yearRecords, (record) => record.taxCents);
        final tip = _sum(yearRecords, (record) => record.tipCents);
        final total = _sum(yearRecords, (record) => record.totalCents);
        final yearCriteria =
            "'All Receipts'!\u0024B\u00245:\u0024B\u0024$lastDataRow";
        rows.add(
          _row(rowNumber, [
            _numberCell('A$rowNumber', year),
            _formulaCell(
              'B$rowNumber',
              'COUNTIF($yearCriteria,A$rowNumber)',
              yearRecords.length,
            ),
            _formulaCell(
              'C$rowNumber',
              "SUMIF($yearCriteria,A$rowNumber,'All Receipts'!\u0024H\u00245:\u0024H\u0024$lastDataRow)",
              subtotal / 100,
              4,
            ),
            _formulaCell(
              'D$rowNumber',
              "SUMIF($yearCriteria,A$rowNumber,'All Receipts'!\u0024I\u00245:\u0024I\u0024$lastDataRow)",
              tax / 100,
              4,
            ),
            _formulaCell(
              'E$rowNumber',
              "SUMIF($yearCriteria,A$rowNumber,'All Receipts'!\u0024J\u00245:\u0024J\u0024$lastDataRow)",
              tip / 100,
              4,
            ),
            _formulaCell(
              'F$rowNumber',
              "SUMIF($yearCriteria,A$rowNumber,'All Receipts'!\u0024K\u00245:\u0024K\u0024$lastDataRow)",
              total / 100,
              7,
            ),
          ]),
        );
      }
    }

    final finalRow = years.isEmpty ? 7 : 6 + years.length;
    return _worksheet(
      rows: rows,
      maxColumn: 'F',
      maxRow: finalRow,
      columnWidths: const [18, 12, 16, 14, 14, 17],
      frozenRows: 6,
      mergedRanges: const ['A1:F1', 'A2:F2'],
      autoFilter: years.isEmpty ? null : 'A6:F$finalRow',
    );
  }

  static String _allReceiptsSheet(
    List<ReceiptExportRecord> records,
    DateTime generatedAt,
  ) {
    final rows = <String>[
      _row(1, [_textCell('A1', 'All Saved Receipts', 1)]),
      _row(2, [
        _textCell(
          'A2',
          'Generated ${DateFormat.yMMMd().add_jm().format(generatedAt)}',
          9,
        ),
      ]),
      _row(4, [
        for (var index = 0; index < _allReceiptHeaders.length; index++)
          _textCell('${_columnName(index + 1)}4', _allReceiptHeaders[index], 2),
      ]),
    ];

    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final rowNumber = index + 5;
      rows.add(
        _row(rowNumber, [
          _dateCell('A$rowNumber', record.date),
          _numberCell('B$rowNumber', record.date.year),
          _numberCell('C$rowNumber', record.date.month),
          _textCell('D$rowNumber', DateFormat.MMMM().format(record.date)),
          _textCell('E$rowNumber', record.merchant, 8),
          _textCell('F$rowNumber', record.category),
          _textCell('G$rowNumber', record.purpose ?? '', 8),
          _moneyCell('H$rowNumber', record.subtotalCents),
          _moneyCell('I$rowNumber', record.taxCents),
          _moneyCell('J$rowNumber', record.tipCents),
          _moneyCell('K$rowNumber', record.totalCents),
          _textCell('L$rowNumber', record.currencyCode),
          _textCell('M$rowNumber', record.paymentMethod ?? ''),
          _textCell('N$rowNumber', record.cardLastFour ?? ''),
          _textCell('O$rowNumber', record.notes ?? '', 8),
          _textCell('P$rowNumber', record.hasPhoto ? 'Yes' : 'No'),
          _textCell('Q$rowNumber', record.id),
        ]),
      );
    }

    final lastDataRow = records.isEmpty ? 5 : records.length + 4;
    final totalRow = records.isEmpty ? 7 : lastDataRow + 2;
    if (records.isEmpty) {
      rows.add(_row(5, [_textCell('A5', 'No saved receipts yet.', 8)]));
    }
    rows.add(
      _row(totalRow, [
        _textCell('A$totalRow', 'Workbook total', 3),
        _formulaCell(
          'H$totalRow',
          'SUM(H5:H$lastDataRow)',
          _sum(records, (record) => record.subtotalCents) / 100,
          7,
        ),
        _formulaCell(
          'I$totalRow',
          'SUM(I5:I$lastDataRow)',
          _sum(records, (record) => record.taxCents) / 100,
          7,
        ),
        _formulaCell(
          'J$totalRow',
          'SUM(J5:J$lastDataRow)',
          _sum(records, (record) => record.tipCents) / 100,
          7,
        ),
        _formulaCell(
          'K$totalRow',
          'SUM(K5:K$lastDataRow)',
          _sum(records, (record) => record.totalCents) / 100,
          7,
        ),
      ]),
    );

    return _worksheet(
      rows: rows,
      maxColumn: 'Q',
      maxRow: totalRow,
      columnWidths: const [
        13,
        9,
        9,
        13,
        24,
        18,
        28,
        14,
        12,
        12,
        15,
        10,
        15,
        12,
        30,
        12,
        28,
      ],
      frozenRows: 4,
      mergedRanges: const ['A1:Q1', 'A2:Q2'],
      autoFilter: records.isEmpty ? null : 'A4:Q$lastDataRow',
    );
  }

  static String _yearSheet(
    int year,
    List<ReceiptExportRecord> records,
    int allReceiptCount,
    DateTime generatedAt,
  ) {
    final allLastRow = allReceiptCount == 0 ? 5 : allReceiptCount + 4;
    final rows = <String>[
      _row(1, [_textCell('A1', '$year Receipts — Organized by Month', 1)]),
      _row(2, [
        _textCell(
          'A2',
          'Generated ${DateFormat.yMMMd().add_jm().format(generatedAt)}',
          9,
        ),
      ]),
      _row(4, [
        _textCell('A4', 'Month', 2),
        _textCell('B4', 'Receipts', 2),
        _textCell('C4', 'Subtotal', 2),
        _textCell('D4', 'Tax', 2),
        _textCell('E4', 'Tip', 2),
        _textCell('F4', 'Total', 2),
      ]),
    ];
    final yearRange = "'All Receipts'!\u0024B\u00245:\u0024B\u0024$allLastRow";
    final monthRange = "'All Receipts'!\u0024C\u00245:\u0024C\u0024$allLastRow";
    for (var month = 1; month <= 12; month++) {
      final rowNumber = month + 4;
      final monthRecords = records
          .where((record) => record.date.month == month)
          .toList();
      rows.add(
        _row(rowNumber, [
          _textCell(
            'A$rowNumber',
            DateFormat.MMMM().format(DateTime(year, month)),
          ),
          _formulaCell(
            'B$rowNumber',
            'COUNTIFS($yearRange,$year,$monthRange,$month)',
            monthRecords.length,
          ),
          for (final column in const [
            ('C', 'H'),
            ('D', 'I'),
            ('E', 'J'),
            ('F', 'K'),
          ])
            _formulaCell(
              '${column.$1}$rowNumber',
              "SUMIFS('All Receipts'!\u0024${column.$2}\u00245:\u0024${column.$2}\u0024$allLastRow,$yearRange,$year,$monthRange,$month)",
              _sum(
                    monthRecords,
                    (record) => switch (column.$2) {
                      'H' => record.subtotalCents,
                      'I' => record.taxCents,
                      'J' => record.tipCents,
                      _ => record.totalCents,
                    },
                  ) /
                  100,
              column.$1 == 'F' ? 7 : 4,
            ),
        ]),
      );
    }

    var nextRow = 18;
    for (var month = 12; month >= 1; month--) {
      final monthRecords = records
          .where((record) => record.date.month == month)
          .toList();
      if (monthRecords.isEmpty) continue;
      rows.add(
        _row(nextRow, [
          _textCell(
            'A$nextRow',
            '${DateFormat.MMMM().format(DateTime(year, month))} — ${monthRecords.length} ${monthRecords.length == 1 ? 'receipt' : 'receipts'}',
            3,
          ),
        ]),
      );
      nextRow++;
      rows.add(
        _row(nextRow, [
          for (var index = 0; index < _yearReceiptHeaders.length; index++)
            _textCell(
              '${_columnName(index + 1)}$nextRow',
              _yearReceiptHeaders[index],
              2,
            ),
        ]),
      );
      final firstDataRow = nextRow + 1;
      for (final record in monthRecords) {
        nextRow++;
        rows.add(
          _row(nextRow, [
            _dateCell('A$nextRow', record.date),
            _textCell('B$nextRow', record.merchant, 8),
            _textCell('C$nextRow', record.category),
            _textCell('D$nextRow', record.purpose ?? '', 8),
            _moneyCell('E$nextRow', record.subtotalCents),
            _moneyCell('F$nextRow', record.taxCents),
            _moneyCell('G$nextRow', record.tipCents),
            _moneyCell('H$nextRow', record.totalCents),
            _textCell('I$nextRow', record.paymentMethod ?? ''),
            _textCell('J$nextRow', record.notes ?? '', 8),
            _textCell('K$nextRow', record.id),
          ]),
        );
      }
      final lastDataRow = nextRow;
      nextRow++;
      rows.add(
        _row(nextRow, [
          _textCell('A$nextRow', 'Month total', 3),
          for (final column in const ['E', 'F', 'G', 'H'])
            _formulaCell(
              '$column$nextRow',
              'SUM($column$firstDataRow:$column$lastDataRow)',
              _sum(
                    monthRecords,
                    (record) => switch (column) {
                      'E' => record.subtotalCents,
                      'F' => record.taxCents,
                      'G' => record.tipCents,
                      _ => record.totalCents,
                    },
                  ) /
                  100,
              7,
            ),
        ]),
      );
      nextRow += 2;
    }

    return _worksheet(
      rows: rows,
      maxColumn: 'K',
      maxRow: nextRow.clamp(18, 1048576),
      columnWidths: const [13, 24, 18, 28, 14, 12, 12, 15, 15, 30, 28],
      frozenRows: 4,
      mergedRanges: [
        'A1:K1',
        'A2:K2',
        for (final row in rows)
          if (row.contains('—') && row.contains('receipt'))
            'A${_rowNumber(row)}:K${_rowNumber(row)}',
      ],
      autoFilter: 'A4:F16',
    );
  }

  static String _worksheet({
    required List<String> rows,
    required String maxColumn,
    required int maxRow,
    required List<double> columnWidths,
    int frozenRows = 0,
    List<String> mergedRanges = const [],
    String? autoFilter,
  }) {
    final columns = StringBuffer('<cols>');
    for (var index = 0; index < columnWidths.length; index++) {
      columns.write(
        '<col min="${index + 1}" max="${index + 1}" '
        'width="${columnWidths[index]}" customWidth="1"/>',
      );
    }
    columns.write('</cols>');
    final pane = frozenRows == 0
        ? ''
        : '<pane ySplit="$frozenRows" topLeftCell="A${frozenRows + 1}" '
              'activePane="bottomLeft" state="frozen"/>';
    final merges = mergedRanges.isEmpty
        ? ''
        : '<mergeCells count="${mergedRanges.length}">'
              '${mergedRanges.map((range) => '<mergeCell ref="$range"/>').join()}'
              '</mergeCells>';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<dimension ref="A1:$maxColumn$maxRow"/>'
        '<sheetViews><sheetView workbookViewId="0" showGridLines="0">$pane</sheetView></sheetViews>'
        '<sheetFormatPr defaultRowHeight="18"/>'
        '$columns'
        '<sheetData>${rows.join()}</sheetData>'
        '$merges'
        '${autoFilter == null ? '' : '<autoFilter ref="$autoFilter"/>'}'
        '<pageMargins left="0.35" right="0.35" top="0.6" bottom="0.6" header="0.2" footer="0.2"/>'
        '</worksheet>';
  }

  static String _row(int number, Iterable<String> cells) {
    return '<row r="$number">${cells.join()}</row>';
  }

  static int _rowNumber(String rowXml) {
    return int.parse(RegExp(r'<row r="(\d+)"').firstMatch(rowXml)!.group(1)!);
  }

  static String _textCell(String reference, String value, [int style = 0]) {
    return '<c r="$reference" s="$style" t="inlineStr"><is><t xml:space="preserve">'
        '${_escape(value)}</t></is></c>';
  }

  static String _numberCell(String reference, num value, [int style = 0]) {
    return '<c r="$reference" s="$style"><v>$value</v></c>';
  }

  static String _moneyCell(String reference, int cents, [int style = 4]) {
    return _numberCell(reference, cents / 100, style);
  }

  static String _dateCell(String reference, DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    // Store at noon so spreadsheet renderers that apply a local timezone do
    // not shift a date-only receipt value into the previous calendar day.
    final serial = day.difference(DateTime.utc(1899, 12, 30)).inDays + 0.5;
    return _numberCell(reference, serial, 5);
  }

  static String _formulaCell(
    String reference,
    String formula,
    num cachedValue, [
    int style = 0,
  ]) {
    return '<c r="$reference" s="$style"><f>${_escape(formula)}</f>'
        '<v>$cachedValue</v></c>';
  }

  static int _sum(
    Iterable<ReceiptExportRecord> records,
    int Function(ReceiptExportRecord) select,
  ) {
    return records.fold<int>(0, (sum, record) => sum + select(record));
  }

  static String _columnName(int number) {
    var value = number;
    final result = StringBuffer();
    while (value > 0) {
      value--;
      result.writeCharCode(65 + value % 26);
      value ~/= 26;
    }
    return result.toString().split('').reversed.join();
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _contentTypes(int sheetCount) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${List.generate(sheetCount, (index) => '<Override PartName="/xl/worksheets/sheet${index + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';
  }

  static const String _rootRelationships =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
      '</Relationships>';

  static String _coreProperties(DateTime generatedAt) {
    final timestamp = generatedAt.toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>Receipt Wallet — All Saved Receipts</dc:title>'
        '<dc:creator>Receipt Wallet</dc:creator>'
        '<dc:subject>Receipts organized by year and month</dc:subject>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$timestamp</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$timestamp</dcterms:modified>'
        '</cp:coreProperties>';
  }

  static String _appProperties(List<_WorkbookSheet> sheets) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Application>Receipt Wallet</Application>'
        '<HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>'
        '<vt:variant><vt:i4>${sheets.length}</vt:i4></vt:variant></vt:vector></HeadingPairs>'
        '<TitlesOfParts><vt:vector size="${sheets.length}" baseType="lpstr">'
        '${sheets.map((sheet) => '<vt:lpstr>${_escape(sheet.name)}</vt:lpstr>').join()}'
        '</vt:vector></TitlesOfParts></Properties>';
  }

  static String _workbook(List<_WorkbookSheet> sheets) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<bookViews><workbookView activeTab="0"/></bookViews><sheets>'
        '${List.generate(sheets.length, (index) => '<sheet name="${_escape(sheets[index].name)}" sheetId="${index + 1}" r:id="rId${index + 1}"/>').join()}'
        '</sheets><calcPr calcId="191029" fullCalcOnLoad="1" forceFullCalc="1"/>'
        '</workbook>';
  }

  static String _workbookRelationships(int sheetCount) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${List.generate(sheetCount, (index) => '<Relationship Id="rId${index + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${index + 1}.xml"/>').join()}'
        '<Relationship Id="rId${sheetCount + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>';
  }

  static const String _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="2"><numFmt numFmtId="164" formatCode="&quot;CA&#36;&quot;#,##0.00"/>'
      '<numFmt numFmtId="165" formatCode="yyyy-mm-dd"/></numFmts>'
      '<fonts count="5">'
      '<font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="18"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FF185C37"/><name val="Calibri"/></font>'
      '<font><i/><sz val="10"/><color rgb="FF52615A"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="4"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF185C37"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFE8F3EC"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left/><right/><top/><bottom style="thin"><color rgb="FFD9E1DC"/></bottom><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="10">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"><alignment horizontal="right"/></xf>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="164" fontId="3" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyNumberFormat="1"><alignment horizontal="right"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"><alignment vertical="top" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';

  static const List<String> _allReceiptHeaders = [
    'Date',
    'Year',
    'Month #',
    'Month',
    'Merchant',
    'Category',
    'Purpose',
    'Subtotal',
    'Tax',
    'Tip',
    'Total',
    'Currency',
    'Payment',
    'Card last 4',
    'Notes',
    'Photo saved',
    'Receipt ID',
  ];

  static const List<String> _yearReceiptHeaders = [
    'Date',
    'Merchant',
    'Category',
    'Purpose',
    'Subtotal',
    'Tax',
    'Tip',
    'Total',
    'Payment',
    'Notes',
    'Receipt ID',
  ];
}

class _WorkbookSheet {
  const _WorkbookSheet({required this.name, required this.xml});

  final String name;
  final String xml;
}
