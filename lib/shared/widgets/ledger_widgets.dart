import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/app/theme/ledger_styles.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';

/// Formats integer cents as "1,482.36" with no currency symbol, the way the
/// paper-ledger design prints every amount.
String ledgerAmount(int cents) {
  return NumberFormat('#,##0.00', 'en_CA').format(cents / 100);
}

/// Uppercase mono date such as "SEP 03".
String ledgerDate(DateTime date) {
  return DateFormat('MMM dd').format(date).toUpperCase();
}

/// A large amount with the cents set in a muted colour: "1,482" ".36".
class LedgerHeroAmount extends StatelessWidget {
  const LedgerHeroAmount({required this.cents, this.size = 52, super.key});

  final int cents;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = ledgerAmount(cents);
    final dot = text.lastIndexOf('.');
    final whole = dot < 0 ? text : text.substring(0, dot);
    final fraction = dot < 0 ? '' : text.substring(dot);
    final style = TextStyle(
      fontFamily: LedgerStyles.monoFamily,
      fontSize: size,
      height: 0.9,
      fontWeight: FontWeight.w700,
      letterSpacing: -size * 0.048,
      color: LedgerStyles.ink(context),
      fontFeatures: LedgerStyles.tabular,
    );
    return Text.rich(
      TextSpan(
        text: whole,
        style: style,
        children: [
          TextSpan(
            text: fraction,
            style: style.copyWith(color: LedgerStyles.inkFaint(context)),
          ),
        ],
      ),
    );
  }
}

/// Section label with an optional trailing action or amount.
class LedgerSectionHeader extends StatelessWidget {
  const LedgerSectionHeader({
    required this.label,
    this.trailing,
    this.underline = false,
    super.key,
  });

  final String label;
  final Widget? trailing;

  /// Draws the heavier ink rule used for week headers in the ledger.
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: underline ? 8 : 0),
      decoration: underline
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: LedgerStyles.ink(context),
                  width: 1.5,
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label, style: LedgerStyles.eyebrow(context))),
          ?trailing,
        ],
      ),
    );
  }
}

/// One hairline-separated row of the ledger: merchant, meta line, amount.
class LedgerRow extends StatelessWidget {
  const LedgerRow({required this.item, required this.onTap, super.key});

  final ReceiptListItem item;
  final VoidCallback onTap;

  static const String businessCategoryId = 'category-business';

  @override
  Widget build(BuildContext context) {
    final receipt = item.receipt;
    final isBusiness = item.category.id == businessCategoryId;
    final detail = isBusiness && (receipt.purpose?.trim().isNotEmpty ?? false)
        ? receipt.purpose!.trim()
        : item.category.name;
    final meta =
        '${ledgerDate(receipt.transactionDate)} · '
        '${detail.toUpperCase()}';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: LedgerStyles.ruleLight(context)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          receipt.merchantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LedgerStyles.rowTitle(context),
                        ),
                      ),
                      if (isBusiness) ...[
                        const SizedBox(width: 7),
                        const LedgerBadge('BIZ'),
                      ],
                      if (receipt.isFavorite) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: LedgerStyles.accent(context),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LedgerStyles.meta(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(
              ledgerAmount(receipt.totalCents),
              style: LedgerStyles.rowAmount(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny outlined mono tag such as "BIZ".
class LedgerBadge extends StatelessWidget {
  const LedgerBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = LedgerStyles.accent(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
      decoration: BoxDecoration(
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: LedgerStyles.monoFamily,
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: accent,
        ),
      ),
    );
  }
}

/// Square mono filter chip: ink when selected, hairline outline otherwise.
class LedgerChip extends StatelessWidget {
  const LedgerChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = LedgerStyles.ink(context);
    final paper = LedgerStyles.paper(context);
    return Material(
      color: selected ? ink : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? ink : LedgerStyles.rule(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Text(
            label.toUpperCase(),
            style: LedgerStyles.chip(
              context,
              color: selected ? paper : LedgerStyles.inkSoft(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline rule between ledger sections.
class LedgerRule extends StatelessWidget {
  const LedgerRule({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: LedgerStyles.rule(context));
  }
}

/// Dashed rule used inside the receipt card.
class LedgerDashedRule extends StatelessWidget {
  const LedgerDashedRule({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashPainter(color: LedgerStyles.rule(context)),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + dash, 0.5), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

/// Centered empty state used by the home and ledger screens.
class LedgerEmptyState extends StatelessWidget {
  const LedgerEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
