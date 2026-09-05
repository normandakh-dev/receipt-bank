import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:receipt_vault_ai/core/storage/receipt_image_storage.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';

abstract final class ReceiptBackupService {
  static const int _formatVersion = 1;
  static const List<String> _requiredCollections = [
    'categories',
    'receipts',
    'receiptItems',
    'tags',
    'receiptTags',
    'appSettings',
  ];

  static Future<File> create(AppDatabase database) async {
    final data = await database.exportBackupData();
    final archive = Archive();
    final manifest = <String, Object?>{
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      ...data,
    };
    archive.add(ArchiveFile.string('manifest.json', jsonEncode(manifest)));

    final addedNames = <String>{};
    for (final receipt in data['receipts']! as List<dynamic>) {
      final storedPath =
          (receipt as Map<String, dynamic>)['imagePath'] as String?;
      final image = await ReceiptImageStorage.resolveFile(storedPath);
      if (image == null) continue;
      final name = path.basename(image.path);
      if (addedNames.add(name)) {
        archive.add(
          ArchiveFile.bytes('images/$name', await image.readAsBytes()),
        );
      }
    }

    final output = File(
      path.join(
        (await getTemporaryDirectory()).path,
        'receipt-wallet-backup-${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    await output.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    return output;
  }

  static Future<int> restore(AppDatabase database, String archivePath) async {
    final decoded = ZipDecoder().decodeBytes(
      await File(archivePath).readAsBytes(),
      verify: true,
    );
    final manifestEntry = decoded.find('manifest.json');
    final manifestBytes = manifestEntry?.readBytes();
    if (manifestBytes == null) throw const FormatException('Missing manifest');
    final manifest = jsonDecode(utf8.decode(manifestBytes));
    if (manifest is! Map<String, dynamic> ||
        manifest['formatVersion'] != _formatVersion ||
        _requiredCollections.any((key) => manifest[key] is! List)) {
      throw const FormatException('Unsupported receipt backup');
    }

    final receiptRows = (manifest['receipts'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
    final imageDirectory = await ReceiptImageStorage.receiptDirectory();
    var restoredImages = 0;
    for (final receipt in receiptRows) {
      final originalPath = receipt['imagePath'] as String?;
      if (originalPath == null) continue;
      final name = path.basename(originalPath);
      final entry = decoded.find('images/$name');
      final bytes = entry?.readBytes();
      if (bytes == null || name.isEmpty) {
        receipt['imagePath'] = null;
        continue;
      }
      await File(
        path.join(imageDirectory.path, name),
      ).writeAsBytes(bytes, flush: true);
      receipt['imagePath'] = path.join('receipt_images', name);
      restoredImages++;
    }

    final restoreData = Map<String, dynamic>.from(manifest);
    restoreData['receipts'] = receiptRows;
    await database.restoreBackupData(restoreData);
    return restoredImages;
  }
}
