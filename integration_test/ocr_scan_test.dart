// Runs the real on-device OCR pipeline (Google ML Kit + ReceiptOcrParser)
// against synthetic receipt images on a device or simulator:
//
//   flutter test integration_test/ocr_scan_test.dart -d <device-id>
//
// Each receipt is painted with Flutter, saved as a PNG, recognised with
// ML Kit, and parsed. The test prints what was detected and asserts the
// fields a person would expect the review screen to prefill.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_ocr_parser.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_text_recognition_service.dart';

class ReceiptCase {
  const ReceiptCase({
    required this.name,
    required this.lines,
    required this.expectMerchant,
    required this.expectTotalCents,
    this.expectTaxCents,
    this.expectDate,
    this.expectPayment,
    this.expectLastFour,
    this.rotationDegrees = 0,
    this.background = const Color(0xFFFFFFFF),
    this.paper = const Color(0xFFFFFFFF),
    this.inkAlpha = 1.0,
    this.fontFamily = 'JetBrainsMono',
    this.fontSize = 26,
    this.noise = 0,
  });

  final String name;
  final List<String> lines;
  final String expectMerchant;
  final int expectTotalCents;
  final int? expectTaxCents;
  final DateTime? expectDate;
  final String? expectPayment;
  final String? expectLastFour;
  final double rotationDegrees;
  final Color background;
  final Color paper;
  final double inkAlpha;
  final String fontFamily;
  final double fontSize;
  final int noise;
}

const cases = [
  ReceiptCase(
    name: 'grocery-gst-pst',
    lines: [
      'SAVE-ON-FOODS #2219',
      '2949 MAIN ST',
      'VANCOUVER BC',
      '2026-09-03 18:42',
      '',
      'OAT MILK 2X          11.98',
      'CHICKEN THIGHS       14.20',
      'PRODUCE              22.76',
      'PANTRY               30.00',
      '',
      'SUBTOTAL             78.94',
      'GST 5%                3.95',
      'PST 7%                5.53',
      'TOTAL                88.42',
      '',
      'VISA ************4021',
      'APPROVED',
      'THANK YOU FOR SHOPPING',
    ],
    expectMerchant: 'Save-On-Foods',
    expectTotalCents: 8842,
    expectTaxCents: 948,
    expectDate: null,
    expectPayment: 'Visa',
    expectLastFour: '4021',
  ),
  ReceiptCase(
    name: 'restaurant-tip-rotated',
    lines: [
      'CACTUS CLUB CAFE',
      '1085 CANADA PLACE',
      'VANCOUVER, BC',
      'Sep 2, 2026  7:15 PM',
      'SERVER: JAMIE  TABLE 12',
      '',
      'BUTTERNUT RAVIOLI     24.00',
      'SPICY CHICKEN         21.50',
      'SPARKLING WATER        4.50',
      '',
      'SUBTOTAL              50.00',
      'GST                    2.50',
      'TIP                    9.00',
      'TOTAL                 61.50',
      '',
      'MASTERCARD  XXXX 7788',
      'CUSTOMER COPY',
    ],
    expectMerchant: 'Cactus Club Cafe',
    expectTotalCents: 6150,
    expectTaxCents: 250,
    expectPayment: 'Mastercard',
    expectLastFour: '7788',
    rotationDegrees: 3,
    background: Color(0xFF8A7B6A),
    paper: Color(0xFFF7F3EA),
    noise: 900,
  ),
  ReceiptCase(
    name: 'gas-station-faded',
    lines: [
      'PETRO-CANADA',
      '4550 KINGSWAY',
      'BURNABY BC V5H 2B9',
      '09/01/2026  08:12',
      'PUMP 04  REGULAR',
      '38.412 L @ 1.669/L',
      '',
      'FUEL SALE            64.10',
      'GST INCLUDED          3.05',
      '',
      'TOTAL                64.10',
      'DEBIT  CHEQUING',
      'ACCT ****2210',
      'AUTH 013377',
    ],
    expectMerchant: 'Petro-Canada',
    expectTotalCents: 6410,
    expectTaxCents: 305,
    expectPayment: 'Debit',
    expectLastFour: '2210',
    inkAlpha: 0.62,
    paper: Color(0xFFF1EFE7),
    rotationDegrees: -2,
    noise: 1500,
  ),
  ReceiptCase(
    name: 'pharmacy-sans-font',
    lines: [
      'London Drugs',
      'Store 34 - 2032 W 41st Ave',
      'Vancouver BC',
      'Date: Aug 28, 2026',
      '',
      'Vitamin D 1000IU        12.99',
      'Bandages assorted        6.49',
      'Toothpaste               4.79',
      '',
      'Subtotal                24.27',
      'GST 5%                   1.21',
      'PST 7%                   0.34',
      'Total tax                1.55',
      'Amount Due              25.82',
      '',
      'Cash                    30.00',
      'Change                   4.18',
    ],
    expectMerchant: 'London Drugs',
    expectTotalCents: 2582,
    expectTaxCents: 155,
    expectPayment: 'Cash',
    fontFamily: 'InstrumentSans',
    fontSize: 27,
  ),
  ReceiptCase(
    name: 'coffee-small-total-below-label',
    lines: [
      'NOMAD COFFEE',
      '123 W HASTINGS ST',
      '03/09/2026 09:02',
      '',
      'FLAT WHITE            5.25',
      'CROISSANT             4.50',
      '',
      'SUBTOTAL              9.75',
      'GST                   0.49',
      'AMOUNT DUE',
      '\$10.24',
      '',
      'VISA DEBIT ...5533',
    ],
    expectMerchant: 'Nomad Coffee',
    expectTotalCents: 1024,
    expectTaxCents: 49,
    expectLastFour: '5533',
    fontSize: 30,
  ),
];

Future<File> paintReceipt(ReceiptCase c, Directory dir) async {
  const width = 1080.0;
  const margin = 70.0;
  final lineHeight = c.fontSize * 1.55;
  final paperHeight = margin * 2 + c.lines.length * lineHeight;
  const canvasW = 1400.0;
  final canvasH = paperHeight + 320;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, canvasW, 4000),
    Paint()..color = c.background,
  );

  canvas.save();
  canvas.translate(canvasW / 2, canvasH / 2);
  canvas.rotate(c.rotationDegrees * math.pi / 180);
  canvas.translate(-width / 2, -paperHeight / 2);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, paperHeight),
    Paint()..color = c.paper,
  );

  final rng = math.Random(7);
  final noisePaint = Paint()..color = const Color(0x22000000);
  for (var i = 0; i < c.noise; i++) {
    canvas.drawCircle(
      Offset(rng.nextDouble() * width, rng.nextDouble() * paperHeight),
      rng.nextDouble() * 1.6,
      noisePaint,
    );
  }

  var y = margin;
  for (final line in c.lines) {
    final painter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontFamily: c.fontFamily,
          fontSize: c.fontSize,
          fontWeight: FontWeight.w500,
          color: Color(0xFF111111).withValues(alpha: c.inkAlpha),
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - margin * 2);
    painter.paint(canvas, Offset(margin, y));
    y += lineHeight;
  }
  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(canvasW.toInt(), canvasH.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path.join(dir.path, '${c.name}.png'));
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  return file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('on-device OCR reads synthetic receipts', (tester) async {
    // Ensure the bundled fonts are loaded before painting.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('warm', style: TextStyle(fontFamily: 'JetBrainsMono')),
              Text('warm', style: TextStyle(fontFamily: 'InstrumentSans')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dir = await getTemporaryDirectory();
    const service = ReceiptTextRecognitionService();
    final report = StringBuffer();
    final failures = <String>[];

    for (final c in cases) {
      final file = await paintReceipt(c, dir);
      final started = DateTime.now();
      final ReceiptScanResult result;
      try {
        result = await service.recognizeFile(file.path);
      } on Object catch (error) {
        failures.add('${c.name}: OCR threw $error');
        continue;
      }
      final elapsed = DateTime.now().difference(started).inMilliseconds;

      report
        ..writeln('==== ${c.name} ($elapsed ms) ====')
        ..writeln('merchant : ${result.merchantName}')
        ..writeln('date     : ${result.transactionDate}')
        ..writeln('subtotal : ${result.subtotalCents}')
        ..writeln('tax      : ${result.taxCents}')
        ..writeln('tip      : ${result.tipCents}')
        ..writeln('total    : ${result.totalCents}')
        ..writeln('payment  : ${result.paymentMethod} ${result.cardLastFour}')
        ..writeln(
          'items    : ${result.items.map((i) => '${i.name}=${i.amountCents}').join(', ')}',
        )
        ..writeln('fields   : ${result.detectedFieldCount}/7')
        ..writeln('--- raw text ---')
        ..writeln(result.rawText)
        ..writeln();

      void check(String field, Object? actual, Object? expected) {
        if (expected != null && actual != expected) {
          failures.add('${c.name}: $field expected $expected, got $actual');
        }
      }

      check('merchant', result.merchantName, c.expectMerchant);
      check('total', result.totalCents, c.expectTotalCents);
      check('tax', result.taxCents, c.expectTaxCents);
      check('payment', result.paymentMethod, c.expectPayment);
      check('lastFour', result.cardLastFour, c.expectLastFour);
      if (c.expectDate != null) {
        check('date', result.transactionDate, c.expectDate);
      } else if (result.transactionDate == null) {
        failures.add('${c.name}: no date detected');
      }
    }

    final reportFile = File(path.join(dir.path, 'ocr-report.txt'));
    await reportFile.writeAsString(report.toString());
    // ignore: avoid_print
    print('OCR_REPORT_BEGIN\n$report\nOCR_REPORT_END');
    // ignore: avoid_print
    print('OCR_FAILURES: ${failures.isEmpty ? 'none' : failures.join(' | ')}');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
