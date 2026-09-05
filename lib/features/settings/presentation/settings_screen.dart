import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_vault_ai/core/backup/receipt_backup_service.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _saveCloudBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ReceiptBackupService.create(
        ref.read(databaseProvider),
      );
      await SharePlus.instance.share(
        ShareParams(
          title: 'Save Receipt Wallet backup to cloud',
          text:
              'Choose iCloud Drive or Google Drive to keep this backup in the cloud. It contains your receipt records and photos.',
          files: [XFile(file.path, mimeType: 'application/zip')],
        ),
      );
    } on Object {
      if (mounted) _message('The backup could not be created.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final selected = await FilePicker.pickFile(
      dialogTitle: 'Choose a Receipt Wallet backup',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace current receipts?'),
        content: const Text(
          'Restoring replaces all receipts, categories, and settings currently on this phone. Create a backup first if you need them.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Restore backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ReceiptBackupService.restore(
        ref.read(databaseProvider),
        selected.xFile.path,
      );
      ref.invalidate(receiptListProvider);
      if (mounted) _message('Backup restored successfully.');
    } on Object {
      if (mounted) _message('That file is not a valid Receipt Wallet backup.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('Save backup to cloud'),
                subtitle: const Text(
                  'Choose iCloud Drive on Apple devices or Google Drive on Android. Includes receipts, categories, and photos.',
                ),
                trailing: const Icon(Icons.ios_share_rounded),
                onTap: _busy ? null : _saveCloudBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Restore cloud backup'),
                subtitle: const Text(
                  'Choose a Receipt Wallet ZIP backup from iCloud Drive, Google Drive, or this device.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _restore,
              ),
            ],
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 16),
        const Text(
          'Cloud backups are manual. Your cloud storage app must be installed and signed in. Receipt Wallet does not upload anything until you choose a destination.',
        ),
      ],
    ),
  );
}
