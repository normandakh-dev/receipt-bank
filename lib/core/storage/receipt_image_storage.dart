import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Produces a reduced-size copy of [source] at [destination].
///
/// Returns the written file, or null when the platform could not compress
/// the image (for example an unsupported format). Callers fall back to
/// copying the original in that case.
typedef ReceiptImageCompressor =
    Future<File?> Function(File source, File destination);

/// Photo usage inside the app's receipt image folder.
typedef ReceiptPhotoUsage = ({int fileCount, int totalBytes});

abstract final class ReceiptImageStorage {
  static const String _directoryName = 'receipt_images';

  /// The shorter side of a stored photo is scaled down to this many pixels.
  ///
  /// A receipt is dark text on light paper, so 1280 pixels across the
  /// narrow side keeps every line legible while the file drops from several
  /// megabytes to a few hundred kilobytes. Text recognition always runs on
  /// the original capture before it is reduced, so OCR accuracy is unchanged.
  static const int maxShorterSidePixels = 1280;

  /// JPEG quality for stored photos. 72 is visually clean for printed text.
  static const int jpegQuality = 72;

  /// Replaceable in tests, where no native image codec is available.
  @visibleForTesting
  static ReceiptImageCompressor compressor = _compressWithPlatform;

  /// Copies the photo at [sourcePath] into the app's receipt folder as a
  /// reduced-size JPEG and returns the portable relative path to store.
  ///
  /// When [deleteSource] is true and the source lives in a temporary or
  /// cache directory (camera captures, picker copies), the source is removed
  /// afterwards so it does not linger on the device.
  static Future<String?> persist(
    String? sourcePath, {
    bool deleteSource = true,
  }) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) {
      return null;
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException(
        'The selected receipt photo is no longer available.',
      );
    }

    final directory = await receiptDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final compressed = File(path.join(directory.path, 'receipt-$stamp.jpg'));

    File stored;
    final reduced = await _tryCompress(source, compressed);
    if (reduced != null) {
      stored = reduced;
    } else {
      final sourceExtension = path.extension(source.path).toLowerCase();
      final extension = _supportedExtensions.contains(sourceExtension)
          ? sourceExtension
          : '.jpg';
      stored = await source.copy(
        path.join(directory.path, 'receipt-$stamp-original$extension'),
      );
    }

    if (deleteSource && await _isTemporaryCapture(source)) {
      try {
        await source.delete();
      } on FileSystemException {
        // The capture will be cleared by the OS cache cleanup instead.
      }
    }

    return path.join(_directoryName, path.basename(stored.path));
  }

  static Future<File?> _tryCompress(File source, File destination) async {
    try {
      final result = await compressor(source, destination);
      if (result == null || !await result.exists()) {
        return null;
      }
      // A tiny or already-optimized source can come out larger; keep the
      // smaller of the two so compression never costs space.
      if (await result.length() >= await source.length()) {
        await result.delete();
        return null;
      }
      return result;
    } on Object {
      return null;
    }
  }

  static Future<File?> _compressWithPlatform(
    File source,
    File destination,
  ) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      source.path,
      destination.path,
      minWidth: maxShorterSidePixels,
      minHeight: maxShorterSidePixels,
      quality: jpegQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    return result == null ? null : File(result.path);
  }

  static Future<bool> _isTemporaryCapture(File file) async {
    final normalized = path.normalize(file.absolute.path);
    try {
      final temporary = path.normalize((await getTemporaryDirectory()).path);
      if (path.isWithin(temporary, normalized)) return true;
    } on Object {
      // Fall through to the segment check below.
    }
    final segments = path.split(normalized).map((s) => s.toLowerCase());
    return segments.any(
      (segment) =>
          segment == 'tmp' || segment == 'cache' || segment == 'caches',
    );
  }

  static Future<File?> resolveFile(String? storedPath) async {
    if (storedPath == null || storedPath.trim().isEmpty) return null;
    final documents = await getApplicationDocumentsDirectory();
    final value = storedPath.trim();
    if (!path.isAbsolute(value)) {
      final relativeFile = File(path.join(documents.path, value));
      return await relativeFile.exists() ? relativeFile : null;
    }

    final absoluteFile = File(value);
    if (await absoluteFile.exists()) return absoluteFile;

    // iOS may assign a new app-container UUID after an update. Recover old
    // absolute paths by locating their filename in the current Documents dir.
    final recovered = File(
      path.join(documents.path, _directoryName, path.basename(value)),
    );
    return await recovered.exists() ? recovered : null;
  }

  static Future<String?> portablePath(String? storedPath) async {
    final file = await resolveFile(storedPath);
    return file == null
        ? null
        : path.join(_directoryName, path.basename(file.path));
  }

  static Future<Directory> receiptDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, _directoryName));
    await directory.create(recursive: true);
    return directory;
  }

  /// Number of stored receipt photos and the bytes they occupy.
  static Future<ReceiptPhotoUsage> photoUsage() async {
    final directory = await receiptDirectory();
    var fileCount = 0;
    var totalBytes = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      fileCount++;
      totalBytes += await entity.length();
    }
    return (fileCount: fileCount, totalBytes: totalBytes);
  }

  static Future<void> deleteOwnedImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    try {
      final directory = await receiptDirectory();
      final directoryPath = path.normalize(directory.path);
      final resolved = await resolveFile(imagePath);
      if (resolved == null) return;
      final candidatePath = path.normalize(resolved.absolute.path);
      if (!path.isWithin(directoryPath, candidatePath)) {
        return;
      }

      final file = File(candidatePath);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // A stale photo must not prevent its receipt row from being removed.
    }
  }

  static const Set<String> _supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
  };
}
