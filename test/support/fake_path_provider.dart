import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Points path_provider at plain directories so storage code runs in tests.
class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform({
    required this.documentsPath,
    required this.temporaryPath,
  });

  final String documentsPath;
  final String temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;

  @override
  Future<String?> getApplicationSupportPath() async => documentsPath;

  @override
  Future<String?> getApplicationCachePath() async => temporaryPath;
}
