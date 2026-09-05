import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

abstract final class ReceiptImageStorage {
  static const String _directoryName = 'receipt_images';

  static Future<String?> persist(String? sourcePath) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) {
      return null;
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException(
        'The selected receipt photo is no longer available.',
      );
    }

    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, _directoryName));
    await directory.create(recursive: true);

    final sourceExtension = path.extension(source.path).toLowerCase();
    final extension = _supportedExtensions.contains(sourceExtension)
        ? sourceExtension
        : '.jpg';
    final fileName =
        'receipt-${DateTime.now().microsecondsSinceEpoch}$extension';
    final destination = File(path.join(directory.path, fileName));
    await source.copy(destination.path);
    return path.join(_directoryName, fileName);
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
