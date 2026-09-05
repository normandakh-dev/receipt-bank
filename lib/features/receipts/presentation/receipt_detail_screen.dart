import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/core/formatters/money_formatter.dart';
import 'package:receipt_vault_ai/core/storage/receipt_image_storage.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/category_visuals.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({required this.receiptId, super.key});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(receiptDetailsProvider(receiptId));

    return details.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This receipt could not be loaded.')),
      ),
      data: (value) {
        if (value == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This receipt no longer exists.')),
          );
        }
        return _ReceiptDetailsView(details: value);
      },
    );
  }
}

class _ReceiptDetailsView extends ConsumerWidget {
  const _ReceiptDetailsView({required this.details});

  final ReceiptDetails details;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this receipt?'),
        content: const Text(
          'The receipt and its line items will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await ref.read(databaseProvider).deleteReceipt(details.receipt.id);
    if (context.mounted) {
      context.go('/receipts');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = details.receipt;
    final colorScheme = Theme.of(context).colorScheme;
    final color = categoryColor(details.category, colorScheme);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt details'),
        actions: [
          IconButton(
            tooltip: receipt.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            onPressed: () => ref
                .read(databaseProvider)
                .setReceiptFavorite(receipt.id, !receipt.isFavorite),
            icon: Icon(
              receipt.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                context.push('/receipts/${receipt.id}/edit');
              } else if (value == 'delete') {
                _delete(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 10),
                    Text('Edit receipt'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded),
                    SizedBox(width: 10),
                    Text('Delete receipt'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withValues(alpha: 0.18),
                  foregroundColor: color,
                  child: Icon(
                    categoryIcon(details.category.iconCode),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  receipt.merchantName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat.yMMMMd().format(receipt.transactionDate),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  MoneyFormatter.formatCents(
                    receipt.totalCents,
                    currencyCode: receipt.currencyCode,
                  ),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                CategoryBadge(category: details.category),
              ],
            ),
          ),
          if (receipt.imagePath case final imagePath?) ...[
            const SizedBox(height: 14),
            _OriginalReceiptPhoto(imagePath: imagePath),
          ],
          if (receipt.purpose case final purpose?) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flag_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase purpose',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(purpose),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount breakdown',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  _AmountRow(label: 'Subtotal', cents: receipt.subtotalCents),
                  _AmountRow(label: 'Tax', cents: receipt.taxCents),
                  if (receipt.tipCents > 0)
                    _AmountRow(label: 'Tip', cents: receipt.tipCents),
                  const Divider(height: 24),
                  _AmountRow(
                    label: 'Total',
                    cents: receipt.totalCents,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
          if (details.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Line items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (
                      var index = 0;
                      index < details.items.length;
                      index++
                    ) ...[
                      if (index > 0) const Divider(height: 20),
                      _ItemRow(item: details.items[index]),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (receipt.paymentMethod != null ||
              receipt.cardLastFour != null) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _InfoRow(
                  icon: Icons.credit_card_rounded,
                  label: 'Payment',
                  value: [
                    receipt.paymentMethod,
                    if (receipt.cardLastFour case final digits?) '•••• $digits',
                  ].whereType<String>().join(' · '),
                ),
              ),
            ),
          ],
          if (receipt.notes case final notes?) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _InfoRow(
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: notes,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OriginalReceiptPhoto extends StatefulWidget {
  const _OriginalReceiptPhoto({required this.imagePath});

  final String imagePath;

  @override
  State<_OriginalReceiptPhoto> createState() => _OriginalReceiptPhotoState();
}

class _OriginalReceiptPhotoState extends State<_OriginalReceiptPhoto> {
  // Resolved once per image path. Creating a new future on every build made
  // the photo card flash a spinner whenever the parent rebuilt, for example
  // when the favorite star was toggled.
  late Future<File?> _imageFile = ReceiptImageStorage.resolveFile(
    widget.imagePath,
  );

  @override
  void didUpdateWidget(covariant _OriginalReceiptPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _imageFile = ReceiptImageStorage.resolveFile(widget.imagePath);
    }
  }

  Future<void> _openPhoto(BuildContext context, File imageFile) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Original receipt'),
            leading: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: ColoredBox(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.file(imageFile, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<File?>(
      future: _imageFile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final imageFile = snapshot.data;
        if (imageFile == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('The original receipt photo is unavailable.'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openPhoto(context, imageFile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    children: [
                      Icon(Icons.image_rounded, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Original receipt photo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.open_in_full_rounded, size: 20),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text('The receipt photo could not be displayed.'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                  child: Text(
                    'Tap to zoom',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.cents,
    this.isTotal = false,
  });

  final String label;
  final int cents;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(MoneyFormatter.formatCents(cents), style: style),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ReceiptItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.quantity > 1 ? '${item.quantity} × ${item.name}' : item.name,
          ),
        ),
        Text(
          MoneyFormatter.formatCents(item.totalPriceCents),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}
