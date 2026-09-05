import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/core/formatters/money_formatter.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/receipt_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(receiptListProvider),
          child: receipts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                _HomeError(onRetry: () => ref.invalidate(receiptListProvider)),
            data: (items) {
              final now = DateTime.now();
              final monthItems = items.where(
                (item) =>
                    item.receipt.transactionDate.year == now.year &&
                    item.receipt.transactionDate.month == now.month,
              );
              final monthTotal = monthItems.fold<int>(
                0,
                (sum, item) => sum + item.receipt.totalCents,
              );
              final allTimeTotal = items.fold<int>(
                0,
                (sum, item) => sum + item.receipt.totalCents,
              );
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Settings and backup',
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Add receipt manually',
                        onPressed: () => context.push('/receipts/new'),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _HeroSummaryCard(
                    monthTotal: monthTotal,
                    receiptCount: monthItems.length,
                    monthName: DateFormat.MMMM().format(now),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallMetricCard(
                          label: 'All time',
                          value: MoneyFormatter.formatCents(allTimeTotal),
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SmallMetricCard(
                          label: 'View and edit',
                          value: 'Categories',
                          icon: Icons.category_rounded,
                          onTap: () => context.push('/home/categories'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: 'Recent receipts',
                    actionLabel: items.isEmpty ? null : 'See all',
                    onAction: items.isEmpty
                        ? null
                        : () => context.go('/receipts'),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    _EmptyHomeCard(onAdd: () => context.push('/receipts/new'))
                  else
                    for (final item in items.take(4)) ...[
                      ReceiptTile(
                        item: item,
                        onTap: () =>
                            context.push('/receipts/${item.receipt.id}'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 18),
                  Card(
                    child: InkWell(
                      onTap: () => context.go('/reports'),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insights_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Explore category reports',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text('See totals and each category’s share.'),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({
    required this.monthTotal,
    required this.receiptCount,
    required this.monthName,
  });

  final int monthTotal;
  final int receiptCount;
  final String monthName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.48)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$monthName spending',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            MoneyFormatter.formatCents(monthTotal),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: colorScheme.onPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                '$receiptCount ${receiptCount == 1 ? 'receipt' : 'receipts'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallMetricCard extends StatelessWidget {
  const _SmallMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (actionLabel case final label?)
          TextButton(onPressed: onAction, child: Text(label)),
      ],
    );
  }
}

class _EmptyHomeCard extends StatelessWidget {
  const _EmptyHomeCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 46),
            const SizedBox(height: 14),
            Text(
              'Your vault is ready',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first receipt to start building spending reports.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add receipt'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline_rounded, size: 48),
        const SizedBox(height: 16),
        Text(
          'Your dashboard could not be loaded.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
