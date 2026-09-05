import 'dart:async';
import 'dart:developer' as developer;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_text_recognition_service.dart';
import 'package:receipt_vault_ai/core/platform/mobile_platform.dart';
import 'package:receipt_vault_ai/features/scanner/presentation/receipt_camera_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final ReceiptTextRecognitionService _recognitionService =
      const ReceiptTextRecognitionService();

  bool _isProcessing = false;
  String _progressLabel = '';
  int _scanGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
  }

  Future<void> _recoverLostImage() async {
    if (!isAndroidOrIos) {
      return;
    }
    try {
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) {
        return;
      }
      final files = response.files;
      if (files != null && files.isNotEmpty) {
        await _recognize(files.first);
      } else if (response.exception != null) {
        _showError('The interrupted image selection could not be recovered.');
      }
    } on Object {
      // Recovery is best-effort and should never block a fresh scan.
    }
  }

  Future<void> _takeAndRecognize() async {
    if (_isProcessing) return;
    final image = await Navigator.of(context, rootNavigator: true).push<XFile>(
      MaterialPageRoute(builder: (context) => const ReceiptCameraScreen()),
    );
    if (image != null) await _recognize(image);
  }

  Future<void> _pickAndRecognize() async {
    if (_isProcessing) {
      return;
    }
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 96,
        maxWidth: 5000,
        maxHeight: 7000,
        requestFullMetadata: false,
      );
      if (image != null) {
        await _recognize(image);
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      final permissionDenied =
          error.code.contains('access_denied') ||
          error.code.contains('permission');
      _showError(
        permissionDenied
            ? 'Camera or photo access was denied. Enable it in device '
                  'settings and try again.'
            : 'The image could not be opened. Please try another photo.',
      );
    } on Object {
      if (mounted) {
        _showError('The image could not be opened. Please try again.');
      }
    }
  }

  Future<void> _importFromFiles() async {
    if (_isProcessing) return;
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Import a receipt image',
        type: FileType.image,
      );
      if (file != null) await _recognize(file.xFile);
    } on PlatformException catch (error) {
      if (!mounted) return;
      final permissionDenied =
          error.code.contains('access_denied') ||
          error.code.contains('permission');
      _showError(
        permissionDenied
            ? 'File access was denied. Enable it in device settings and try again.'
            : 'The receipt image could not be imported. Please try another file.',
      );
    } on Object {
      if (mounted) {
        _showError(
          'The receipt image could not be imported. Please try again.',
        );
      }
    }
  }

  Future<void> _recognize(XFile image) async {
    final generation = ++_scanGeneration;
    setState(() {
      _isProcessing = true;
      _progressLabel = 'Reading receipt text on this device…';
    });
    try {
      final result = await _recognitionService
          .recognizeFile(image.path)
          .timeout(const Duration(seconds: 30));
      if (!mounted || generation != _scanGeneration) {
        return;
      }
      if (result.rawText.isEmpty) {
        _showError(
          'No readable text was found. Try brighter light, hold the camera '
          'parallel to the receipt, or enter it manually.',
        );
        return;
      }
      // The OCR job is complete. Do not keep the scanner locked while the
      // review route is open; this route remains alive in the tab shell.
      _setIdle(generation);
      await context.push('/receipts/new', extra: result);
    } on TimeoutException {
      if (mounted && generation == _scanGeneration) {
        _showError(
          'Reading this photo took too long. Try again with the receipt '
          'closer, flatter, and in brighter light.',
        );
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Receipt OCR failed',
        name: 'receipt_vault.ocr',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && generation == _scanGeneration) {
        _showError(
          'Receipt text could not be read. Try another photo or enter it '
          'manually.',
        );
      }
    } finally {
      _setIdle(generation);
    }
  }

  void _setIdle(int generation) {
    if (!mounted || generation != _scanGeneration || !_isProcessing) {
      return;
    }
    setState(() {
      _isProcessing = false;
      _progressLabel = '';
    });
  }

  void _cancelRecognition() {
    _scanGeneration++;
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _progressLabel = '';
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Text(
              'Scan a receipt',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Take a clear photo or choose one from your library. You can '
              'review and correct every detected field before saving.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _ScannerFrame(isProcessing: _isProcessing),
            const SizedBox(height: 18),
            if (_isProcessing)
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _progressLabel,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelRecognition,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: _takeAndRecognize,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take receipt photo'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickAndRecognize,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Choose from photos'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _importFromFiles,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Import from Files'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/receipts/new'),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Enter manually instead'),
              ),
            ],
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private and reviewable',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    const _FeatureRow(
                      icon: Icons.phonelink_lock_rounded,
                      text: 'Text recognition runs on this device',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureRow(
                      icon: Icons.fact_check_rounded,
                      text: 'Merchant, date, and amounts are fully editable',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureRow(
                      icon: Icons.auto_awesome_rounded,
                      text: 'Purpose and category are suggested automatically',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({required this.isProcessing});

  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isProcessing
                      ? Icons.document_scanner_rounded
                      : Icons.receipt_long_rounded,
                  size: 58,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  isProcessing ? 'Detecting receipt fields' : 'Fill the frame',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Stay 15–25 cm away, then zoom and tap to focus',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            for (final alignment in const [
              Alignment.topLeft,
              Alignment.topRight,
              Alignment.bottomLeft,
              Alignment.bottomRight,
            ])
              Align(
                alignment: alignment,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    Icons.crop_free_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
