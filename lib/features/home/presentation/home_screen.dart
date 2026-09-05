import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/app/theme/ledger_styles.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/ledger_widgets.dart';

/// "Home · This month" from the paper-ledger design: the month total leads,
/// then top categories as a stacked bar, then the latest receipts.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptListProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(receiptListProvider),
          child: receipts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                _HomeError(onRetry: () => ref.invalidate(receiptListProvider)),
            data: (items) => _HomeLedger(items: items),
          ),
        ),
      ),
    );
  }
}

class _HomeLedger extends StatelessWidget {
  const _HomeLedger({required this.items});

  final List<ReceiptListItem> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final previousStart = DateTime(now.year, now.month - 1);

    final monthItems = items
        .where(
          (item) =>
              !item.receipt.transactionDate.isBefore(monthStart) &&
              item.receipt.transactionDate.isBefore(nextMonth),
        )
        .toList(growable: false);
    final previousItems = items.where(
      (item) =>
          !item.receipt.transactionDate.isBefore(previousStart) &&
          item.receipt.transactionDate.isBefore(monthStart),
    );
    final monthTotal = _sum(monthItems);
    final previousTotal = _sum(previousItems);
    final summaries = _topCategories(monthItems.isEmpty ? items : monthItems);
    final topLabel = monthItems.isEmpty && items.isNotEmpty
        ? 'TOP CATEGORIES · ALL TIME'
        : 'TOP CATEGORIES';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    '${DateFormat('MMM yyyy').format(now).toUpperCase()} · '
                    '${monthItems.length} '
                    '${monthItems.length == 1 ? 'RECEIPT' : 'RECEIPTS'}',
                    style: LedgerStyles.eyebrow(context),
                  ),
                  const SizedBox(height: 14),
                  LedgerHeroAmount(cents: monthTotal),
                  const SizedBox(height: 12),
                  _MonthComparison(
                    monthTotal: monthTotal,
                    previousTotal: previousTotal,
                    previousMonthName: DateFormat.MMMM().format(previousStart),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Settings and backup',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const LedgerRule(),
        const SizedBox(height: 22),
        LedgerSectionHeader(
          label: topLabel,
          trailing: items.isEmpty
              ? null
              : _InlineLink(
                  label: 'All',
                  onTap: () => context.push('/reports/categories'),
                ),
        ),
        const SizedBox(height: 14),
        if (summaries.isEmpty)
          Text(
            'Category shares appear once a receipt is saved.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else ...[
          _ShareBar(summaries: summaries),
          const SizedBox(height: 14),
          for (var index = 0; index < summaries.length; index++) ...[
            if (index > 0) const SizedBox(height: 9),
            _CategoryShareRow(summary: summaries[index], index: index),
          ],
        ],
        const SizedBox(height: 22),
        const LedgerRule(),
        const SizedBox(height: 22),
        LedgerSectionHeader(
          label: 'LATEST',
          trailing: items.isEmpty
              ? null
              : _InlineLink(
                  label: 'See all',
                  onTap: () => context.go('/receipts'),
                ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          LedgerEmptyState(
            title: 'Your ledger is empty',
            message:
                'Scan or add your first receipt to start building spending '
                'reports.',
            actionLabel: 'Add receipt',
            onAction: () => context.push('/receipts/new'),
          )
        else
          for (final item in items.take(4))
            LedgerRow(
              item: item,
              onTap: () => context.push('/receipts/${item.receipt.id}'),
            ),
      ],
    );
  }

  static int _sum(Iterable<ReceiptListItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.receipt.totalCents);
  }

  static List<_CategoryShare> _topCategories(List<ReceiptListItem> items) {
    if (items.isEmpty) return const [];
    final totals = <String, _CategoryShare>{};
    for (final item in items) {
      totals.update(
        item.category.id,
        (value) => _CategoryShare(
          category: value.category,
          cents: value.cents + item.receipt.totalCents,
        ),
        ifAbsent: () => _CategoryShare(
          category: item.category,
          cents: item.receipt.totalCents,
        ),
      );
    }
    final ordered = totals.values.toList()
      ..sort((a, b) => b.cents.compareTo(a.cents));
    final top = ordered.take(3).toList();
    final rest = ordered.skip(3).fold<int>(0, (sum, s) => sum + s.cents);
    if (rest > 0) {
      top.add(_CategoryShare(category: null, cents: rest));
    }
    return top;
  }
}

class _CategoryShare {
  const _CategoryShare({required this.category, required this.cents});

  final Category? category;
  final int cents;

  String get name => category?.name ?? 'Everything else';
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.summaries});

  final List<_CategoryShare> summaries;

  @override
  Widget build(BuildContext context) {
    final scale = LedgerStyles.shareScale(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 10,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < summaries.length; index++) ...[
              if (index > 0) const SizedBox(width: 2),
              Expanded(
                flex: summaries[index].cents.clamp(1, 1 << 30),
                child: ColoredBox(
                  color: summaries[index].category == null
                      ? scale.last
                      : scale[index.clamp(0, scale.length - 2)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryShareRow extends StatelessWidget {
  const _CategoryShareRow({required this.summary, required this.index});

  final _CategoryShare summary;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scale = LedgerStyles.shareScale(context);
    final color = summary.category == null
        ? scale.last
        : scale[index.clamp(0, scale.length - 2)];
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            summary.name,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 14, height: 1),
          ),
        ),
        Text(
          ledgerAmount(summary.cents),
          style: LedgerStyles.rowAmount(
            context,
          ).copyWith(fontSize: 14, letterSpacing: 0),
        ),
      ],
    );
  }
}

class _MonthComparison extends StatelessWidget {
  const _MonthComparison({
    required this.monthTotal,
    required this.previousTotal,
    required this.previousMonthName,
  });

  final int monthTotal;
  final int previousTotal;
  final String previousMonthName;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (previousTotal == 0) {
      text = monthTotal == 0
          ? 'Nothing recorded yet'
          : 'No receipts in $previousMonthName';
    } else {
      final change = (monthTotal - previousTotal) / previousTotal;
      final percent = (change.abs() * 100).round();
      text = percent == 0
          ? 'Same as $previousMonthName'
          : change < 0
          ? '$percent% under $previousMonthName'
          : '$percent% over $previousMonthName';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: LedgerStyles.accent(context),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontFamily: LedgerStyles.sansFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: LedgerStyles.inkSoft(context),
          ),
        ),
      ],
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: LedgerStyles.sansFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: LedgerStyles.accent(context),
          ),
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
          'Your ledger could not be loaded.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
