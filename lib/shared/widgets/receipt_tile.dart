import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/core/formatters/money_formatter.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/shared/widgets/category_visuals.dart';

class ReceiptTile extends StatelessWidget {
  const ReceiptTile({required this.item, required this.onTap, super.key});

  final ReceiptListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final receipt = item.receipt;
    final colorScheme = Theme.of(context).colorScheme;
    final color = categoryColor(item.category, colorScheme);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(categoryIcon(item.category.iconCode), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            receipt.merchantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (receipt.isFavorite)
                          Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: colorScheme.tertiary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.category.name} · '
                      '${DateFormat.MMMd().format(receipt.transactionDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (receipt.purpose case final purpose?) ...[
                      const SizedBox(height: 3),
                      Text(
                        purpose,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                MoneyFormatter.formatCents(
                  receipt.totalCents,
                  currencyCode: receipt.currencyCode,
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
