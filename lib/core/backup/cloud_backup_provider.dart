abstract interface class CloudBackupProvider {
  String get providerId;

  Future<void> uploadBackup({required String localBackupPath});

  Future<String> downloadLatestBackup({required String destinationDirectory});
}
