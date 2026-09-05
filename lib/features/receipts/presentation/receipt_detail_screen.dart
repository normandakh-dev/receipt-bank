import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/app/theme/ledger_styles.dart';
import 'package:receipt_vault_ai/core/storage/receipt_image_storage.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/ledger_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// "Detail · Receipt as object" from the paper-ledger design: the receipt is
/// drawn as a printed slip on a deeper paper ground, followed by a short
/// ledger of category, purpose, photo, and notes.
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

class _ReceiptDetailsView extends ConsumerStatefulWidget {
  const _ReceiptDetailsView({required this.details});

  final ReceiptDetails details;

  @override
  ConsumerState<_ReceiptDetailsView> createState() =>
      _ReceiptDetailsViewState();
}

class _ReceiptDetailsViewState extends ConsumerState<_ReceiptDetailsView> {
  // Resolved once per image path so parent rebuilds (favorite toggles) do
  // not flash the photo row.
  late Future<File?> _imageFile = ReceiptImageStorage.resolveFile(
    widget.details.receipt.imagePath,
  );

  @override
  void didUpdateWidget(covariant _ReceiptDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.details.receipt.imagePath !=
        widget.details.receipt.imagePath) {
      _imageFile = ReceiptImageStorage.resolveFile(
        widget.details.receipt.imagePath,
      );
    }
  }

  Receipt get _receipt => widget.details.receipt;

  Future<void> _delete() async {
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
    if (confirmed != true || !mounted) return;
    await ref.read(databaseProvider).deleteReceipt(_receipt.id);
    if (mounted) context.go('/receipts');
  }

  Future<void> _share() async {
    final receipt = _receipt;
    final summary =
        '${receipt.merchantName} · '
        '${DateFormat.yMMMd().format(receipt.transactionDate)} · '
        '${receipt.currencyCode} ${ledgerAmount(receipt.totalCents)}';
    final image = await _imageFile;
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share receipt',
          text: summary,
          files: image == null ? null : [XFile(image.path)],
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The receipt could not be shared.')),
        );
      }
    }
  }

  Future<void> _openPhoto(File imageFile) {
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
    final receipt = _receipt;
    final details = widget.details;
    final accent = LedgerStyles.accent(context);

    return Scaffold(
      backgroundColor: LedgerStyles.paperDeep(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/receipts'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(),
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
                    color: receipt.isFavorite ? accent : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Share receipt',
                  onPressed: _share,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.push('/receipts/${receipt.id}/edit');
                    } else if (value == 'delete') {
                      _delete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit receipt')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete receipt'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _ReceiptSlip(details: details),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  _LedgerField(
                    label: 'CATEGORY',
                    value: details.category.name,
                    trailingIcon: Icons.edit_outlined,
                    onTap: () => context.push('/receipts/${receipt.id}/edit'),
                  ),
                  _LedgerField(
                    label: 'PURPOSE',
                    value: receipt.purpose?.trim().isNotEmpty ?? false
                        ? receipt.purpose!.trim()
                        : 'Not set',
                    muted: !(receipt.purpose?.trim().isNotEmpty ?? false),
                    trailingIcon: Icons.edit_outlined,
                    onTap: () => context.push('/receipts/${receipt.id}/edit'),
                  ),
                  if (receipt.imagePath != null)
                    FutureBuilder<File?>(
                      future: _imageFile,
                      builder: (context, snapshot) {
                        final file = snapshot.data;
                        final pending =
                            snapshot.connectionState != ConnectionState.done;
                        return _LedgerField(
                          label: 'PHOTO',
                          value: pending
                              ? 'Locating…'
                              : file == null
                              ? 'Photo unavailable'
                              : 'View original',
                          accent: file != null,
                          muted: file == null,
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: file == null ? null : () => _openPhoto(file),
                        );
                      },
                    ),
                  if (receipt.notes case final notes?)
                    _LedgerField(label: 'NOTES', value: notes, last: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The receipt drawn as a printed slip.
class _ReceiptSlip extends StatelessWidget {
  const _ReceiptSlip({required this.details});

  final ReceiptDetails details;

  @override
  Widget build(BuildContext context) {
    final receipt = details.receipt;
    final muted = LedgerStyles.inkSoft(context);
    final lineStyle = LedgerStyles.receiptLine(context);
    final mutedLine = LedgerStyles.receiptLine(context, color: muted);
    final captured = receipt.rawOcrText == null
        ? 'ENTERED MANUALLY'
        : 'CAPTURED ON DEVICE';
    final payment = [
      if (receipt.paymentMethod case final method?) method.toUpperCase(),
      if (receipt.cardLastFour case final digits?) '···· $digits',
    ].join(' ');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      decoration: BoxDecoration(
        color: LedgerStyles.paperCard(context),
        boxShadow: [
          BoxShadow(
            color: LedgerStyles.ink(context).withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: -14,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            receipt.merchantName.toUpperCase(),
            textAlign: TextAlign.center,
            style: LedgerStyles.eyebrow(
              context,
            ).copyWith(letterSpacing: 2, height: 1.3),
          ),
          const SizedBox(height: 7),
          Text(
            DateFormat(
              'MMM dd yyyy',
            ).format(receipt.transactionDate).toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: LedgerStyles.monoFamily,
              fontSize: 11,
              height: 1.4,
              color: muted,
            ),
          ),
          const SizedBox(height: 20),
          const LedgerDashedRule(),
          if (details.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < details.items.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(height: 11),
                    _SlipLine(
                      label: _itemLabel(details.items[index]),
                      amount: details.items[index].totalPriceCents,
                      style: lineStyle,
                    ),
                  ],
                ],
              ),
            ),
            const LedgerDashedRule(),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                _SlipLine(
                  label: 'SUBTOTAL',
                  amount: receipt.subtotalCents,
                  style: mutedLine,
                ),
                const SizedBox(height: 9),
                _SlipLine(
                  label: 'TAX',
                  amount: receipt.taxCents,
                  style: mutedLine,
                ),
                if (receipt.tipCents > 0) ...[
                  const SizedBox(height: 9),
                  _SlipLine(
                    label: 'TIP',
                    amount: receipt.tipCents,
                    style: mutedLine,
                  ),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: LedgerStyles.ink(context), width: 1.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'TOTAL',
                    style: LedgerStyles.eyebrow(
                      context,
                      color: LedgerStyles.ink(context),
                    ).copyWith(fontSize: 12),
                  ),
                ),
                Text(
                  ledgerAmount(receipt.totalCents),
                  style: TextStyle(
                    fontFamily: LedgerStyles.monoFamily,
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.4,
                    color: LedgerStyles.ink(context),
                    fontFeatures: LedgerStyles.tabular,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            [if (payment.isNotEmpty) payment, captured].join('\n'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: LedgerStyles.monoFamily,
              fontSize: 11,
              height: 1.5,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  static String _itemLabel(ReceiptItem item) {
    final name = item.name.toUpperCase();
    return item.quantity > 1 ? '$name ×${item.quantity}' : name;
  }
}

class _SlipLine extends StatelessWidget {
  const _SlipLine({
    required this.label,
    required this.amount,
    required this.style,
  });

  final String label;
  final int amount;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 12),
        Text(ledgerAmount(amount), style: style),
      ],
    );
  }
}

class _LedgerField extends StatelessWidget {
  const _LedgerField({
    required this.label,
    required this.value,
    this.trailingIcon,
    this.onTap,
    this.accent = false,
    this.muted = false,
    this.last = false,
  });

  final String label;
  final String value;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final bool accent;
  final bool muted;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? LedgerStyles.accent(context)
        : muted
        ? LedgerStyles.inkSoft(context)
        : LedgerStyles.ink(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: LedgerStyles.rule(context))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  label,
                  style: LedgerStyles.eyebrow(
                    context,
                  ).copyWith(letterSpacing: 1.4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: LedgerStyles.sansFamily,
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 12),
              Icon(
                trailingIcon,
                size: 19,
                color: accent
                    ? LedgerStyles.accent(context)
                    : LedgerStyles.inkSoft(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
