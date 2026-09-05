import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ReceiptCameraScreen extends StatefulWidget {
  const ReceiptCameraScreen({super.key});

  @override
  State<ReceiptCameraScreen> createState() => _ReceiptCameraScreenState();
}

class _ReceiptCameraScreenState extends State<ReceiptCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _zoomAtScaleStart = 1;
  Offset? _focusPoint;
  Timer? _focusIndicatorTimer;
  FlashMode _flashMode = FlashMode.auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      if (controller != null && controller.value.isInitialized) {
        _disposeController();
      }
    } else if (state == AppLifecycleState.resumed) {
      // The controller was released when the app went inactive, so it is
      // null here; a fresh one must be created or the preview stays black.
      if (controller == null && _errorMessage == null && !_isInitializing) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }
    try {
      final cameras = await availableCameras();
      final rearCameras = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList(growable: false);
      if (rearCameras.isEmpty) {
        throw CameraException('NoRearCamera', 'No rear camera is available.');
      }

      await _disposeController();
      final controller = CameraController(
        rearCameras.first,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      final zoomLevels = await Future.wait([
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
      ]);
      _minZoom = zoomLevels[0];
      _maxZoom = zoomLevels[1];
      // A little optical/digital zoom lets the user stay outside the lens's
      // minimum focus distance while still filling the frame with the receipt.
      _zoom = 1.5.clamp(_minZoom, _maxZoom).toDouble();
      await controller.setZoomLevel(_zoom);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(const Offset(0.5, 0.5));
      try {
        await controller.setFlashMode(_flashMode);
      } on CameraException {
        _flashMode = FlashMode.off;
      }
      if (mounted) setState(() => _isInitializing = false);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = switch (error.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
            'Camera access is off. Enable it in Settings, then try again.',
          'CameraAccessRestricted' =>
            'Camera access is restricted on this phone.',
          _ => 'The camera could not start. Please try again.',
        };
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'The camera could not start. Please try again.';
      });
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }

  Future<void> _focus(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final point = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0, 1),
      (details.localPosition.dy / constraints.maxHeight).clamp(0, 1),
    );
    setState(() => _focusPoint = details.localPosition);
    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } on CameraException {
      // Some cameras do not expose metering points; autofocus still runs.
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtScaleStart = _zoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    if (details.pointerCount != 2) return;
    final nextZoom = (_zoomAtScaleStart * details.scale)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    if ((nextZoom - _zoom).abs() < 0.02) return;
    _zoom = nextZoom;
    if (mounted) setState(() {});
    try {
      await _controller?.setZoomLevel(_zoom);
    } on CameraException {
      // Ignore a zoom update if the camera is closing.
    }
  }

  Future<void> _setZoom(double value) async {
    _zoom = value.clamp(_minZoom, _maxZoom).toDouble();
    setState(() {});
    await _controller?.setZoomLevel(_zoom);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      setState(() => _flashMode = next);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flash is not available on this camera.'),
          ),
        );
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(const Offset(0.5, 0.5));
      final image = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(image);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The photo could not be taken. Try again.'),
          ),
        );
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusIndicatorTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _errorMessage != null
            ? _CameraError(message: _errorMessage!, retry: _initializeCamera)
            : _isInitializing || !(_controller?.value.isInitialized ?? false)
            ? const Center(child: CircularProgressIndicator())
            : _buildCamera(),
      ),
    );
  }

  Widget _buildCamera() {
    final controller = _controller!;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _focus(details, constraints),
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize!.height,
                    height: controller.value.previewSize!.width,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 104, 24, 154),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ),
        if (_focusPoint case final point?)
          Positioned(
            left: point.dx - 24,
            top: point.dy - 24,
            child: const IgnorePointer(
              child: Icon(
                Icons.filter_center_focus,
                color: Colors.amber,
                size: 48,
              ),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          top: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
              IconButton.filledTonal(
                tooltip: _flashMode == FlashMode.off
                    ? 'Auto flash'
                    : 'Flash off',
                onPressed: _toggleFlash,
                icon: Icon(
                  _flashMode == FlashMode.off
                      ? Icons.flash_off_rounded
                      : Icons.flash_auto_rounded,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 18,
          child: Column(
            children: [
              const Text(
                'Tap text to focus · Pinch or use zoom to stay farther away',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final zoom in const [1.0, 1.5, 2.0])
                    if (zoom >= _minZoom && zoom <= _maxZoom)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            '${zoom.toStringAsFixed(zoom == 1 ? 0 : 1)}×',
                          ),
                          selected: (_zoom - zoom).abs() < 0.15,
                          onSelected: (_) => _setZoom(zoom),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Take receipt photo',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isCapturing ? null : _capture,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white54, width: 5),
                    ),
                    alignment: Alignment.center,
                    child: _isCapturing
                        ? const SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(Icons.document_scanner_rounded, size: 34),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              color: Colors.white,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: retry, child: const Text('Try again')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
