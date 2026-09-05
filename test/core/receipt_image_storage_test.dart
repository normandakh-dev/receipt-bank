import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:receipt_vault_ai/core/storage/receipt_image_storage.dart';

import '../support/fake_path_provider.dart';

void main() {
  late Directory root;
  late Directory documents;
  late Directory temporary;
  late Directory elsewhere;
  final compressedBytes = List<int>.generate(64, (index) => index);
  final originalBytes = List<int>.filled(4096, 7);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('receipt-storage-test');
    documents = await Directory(path.join(root.path, 'Documents')).create();
    temporary = await Directory(path.join(root.path, 'tmp')).create();
    elsewhere = await Directory(path.join(root.path, 'Library')).create();
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: documents.path,
      temporaryPath: temporary.path,
    );
    ReceiptImageStorage.compressor = (source, destination) async {
      await destination.writeAsBytes(compressedBytes, flush: true);
      return destination;
    };
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<File> capture(Directory directory, String name) {
    return File(
      path.join(directory.path, name),
    ).writeAsBytes(originalBytes, flush: true);
  }

  test(
    'stores a reduced JPEG copy and removes the temporary capture',
    () async {
      final source = await capture(temporary, 'capture.heic');

      final stored = await ReceiptImageStorage.persist(source.path);

      expect(stored, startsWith('receipt_images${path.separator}receipt-'));
      expect(stored, endsWith('.jpg'));
      final file = File(path.join(documents.path, stored));
      expect(await file.readAsBytes(), compressedBytes);
      expect(await source.exists(), isFalse);
    },
  );

  test('keeps the original photo when compression is unavailable', () async {
    ReceiptImageStorage.compressor = (source, destination) async => null;
    final source = await capture(temporary, 'capture.png');

    final stored = await ReceiptImageStorage.persist(source.path);

    expect(stored, endsWith('-original.png'));
    final file = File(path.join(documents.path, stored));
    expect(await file.length(), originalBytes.length);
  });

  test('keeps the original when the reduced copy is not smaller', () async {
    ReceiptImageStorage.compressor = (source, destination) async {
      await destination.writeAsBytes(
        List<int>.filled(originalBytes.length + 1, 1),
        flush: true,
      );
      return destination;
    };
    final source = await capture(temporary, 'capture.jpg');

    final stored = await ReceiptImageStorage.persist(source.path);

    expect(stored, endsWith('-original.jpg'));
    final usage = await ReceiptImageStorage.photoUsage();
    expect(usage.fileCount, 1);
    expect(usage.totalBytes, originalBytes.length);
  });

  test('never deletes a source photo outside temporary storage', () async {
    final source = await capture(elsewhere, 'keep-me.jpg');

    await ReceiptImageStorage.persist(source.path);

    expect(await source.exists(), isTrue);
  });

  test('reports how many photos are stored and their size', () async {
    await ReceiptImageStorage.persist(
      (await capture(temporary, 'one.jpg')).path,
    );
    await ReceiptImageStorage.persist(
      (await capture(temporary, 'two.jpg')).path,
    );

    final usage = await ReceiptImageStorage.photoUsage();

    expect(usage.fileCount, 2);
    expect(usage.totalBytes, compressedBytes.length * 2);
  });
}
