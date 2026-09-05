import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_ocr_parser.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_ocr_text_layout.dart';

class ReceiptTextRecognitionService {
  const ReceiptTextRecognitionService();

  Future<ReceiptScanResult> recognizeFile(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);
      final layoutText = ReceiptOcrTextLayout.arrange(
        recognizedText.blocks.expand(
          (block) => block.lines.map(
            (line) => ReceiptOcrTextFragment(
              text: line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              width: line.boundingBox.width,
              height: line.boundingBox.height,
            ),
          ),
        ),
        fallback: recognizedText.text,
      );
      return ReceiptOcrParser.parse(layoutText).withSourceImagePath(imagePath);
    } finally {
      await recognizer.close();
    }
  }
}
