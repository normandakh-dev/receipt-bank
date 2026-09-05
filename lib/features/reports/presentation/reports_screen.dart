import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/app/theme/ledger_styles.dart';
import 'package:receipt_vault_ai/core/analytics/spending_report_calculator.dart';
import 'package:receipt_vault_ai/core/export/receipt_excel_export_service.dart';
import 'package:receipt_vault_ai/core/export/receipt_excel_workbook_builder.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/category_visuals.dart';
import 'package:receipt_vault_ai/shared/widgets/ledger_widgets.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  SpendingReportGrouping _grouping = SpendingReportGrouping.monthly;
  bool _isExportingExcel = false;

  Future<void> _exportExcel(List<ReceiptListItem> items) async {
    if (items.isEmpty || _isExportingExcel) return;
    setState(() => _isExportingExcel = true);
    try {
      final records = items.map(ReceiptExportRecord.fromListItem).toList();
      final file = await ReceiptExcelExportService.createExcelFile(records);
      final fileName = file.uri.pathSegments.last;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Save all receipts to Excel',
          subject: 'Receipt Wallet — all saved receipts',
          text:
              'All Receipt Wallet records are attached in an Excel workbook, '
              'organized by year and month.',
          files: [
            XFile(
              file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: fileName,
            ),
          ],
        ),
      );
      if (result.status == ShareResultStatus.unavailable && mounted) {
        _showExportError();
      }
    } on Object {
      if (mounted) _showExportError();
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  void _showExportError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'The Excel workbook could not be prepared. Please try again.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(receiptListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: receipts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(receiptListProvider),
              child: const Text('Try again'),
            ),
          ),
          data: (items) {
            final allTimeTotal = items.fold<int>(
              0,
              (sum, item) => sum + item.receipt.totalCents,
            );
            final records = items
                .map(
                  (item) => SpendingRecord(
                    date: item.receipt.transactionDate,
                    cents: item.receipt.totalCents,
                  ),
                )
                .toList(growable: false);
            final periodTotals = SpendingReportCalculator.group(
              records,
              _grouping,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              children: [
                Text('REPORTS', style: LedgerStyles.eyebrow(context)),
                const SizedBox(height: 10),
                Text(
                  'Where money went',
                  style: LedgerStyles.screenTitle(context),
                ),
                const SizedBox(height: 18),
                _OverallTotalCard(
                  totalCents: allTimeTotal,
                  receiptCount: items.length,
                ),
                const SizedBox(height: 28),
                SegmentedButton<SpendingReportGrouping>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: SpendingReportGrouping.weekly,
                      label: Text('Weekly'),
                    ),
                    ButtonSegment(
                      value: SpendingReportGrouping.monthly,
                      label: Text('Monthly'),
                    ),
                    ButtonSegment(
                      value: SpendingReportGrouping.yearly,
                      label: Text('Yearly'),
                    ),
                  ],
                  selected: {_grouping},
                  onSelectionChanged: (selection) {
                    setState(() => _grouping = selection.single);
                  },
                ),
                const SizedBox(height: 12),
                if (periodTotals.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Period totals will appear after a receipt is saved.',
                      ),
                    ),
                  )
                else
                  for (final period in periodTotals) ...[
                    _PeriodSummaryTile(
                      period: period,
                      grouping: _grouping,
                      onTap: () => _openPeriod(context, period, _grouping),
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: Icon(
                      Icons.donut_large_rounded,
                      color: colorScheme.primary,
                    ),
                    title: const Text('Spending by category'),
                    subtitle: const Text('View totals for every category'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/reports/categories'),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    leading: Icon(
                      Icons.table_view_rounded,
                      color: items.isEmpty
                          ? colorScheme.outline
                          : colorScheme.primary,
                    ),
                    title: const Text('Export all receipts to Excel'),
                    subtitle: Text(
                      items.isEmpty
                          ? 'Save a receipt before exporting.'
                          : 'Summary, all receipts, and yearly sheets organized by month',
                    ),
                    trailing: _isExportingExcel
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    onTap: items.isEmpty || _isExportingExcel
                        ? null
                        : () => _exportExcel(items),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openPeriod(
    BuildContext context,
    SpendingPeriodTotal period,
    SpendingReportGrouping grouping,
  ) {
    final query = Uri(
      queryParameters: {
        'from': _dateParameter(period.start),
        'to': _dateParameter(period.endExclusive),
        'period': _periodLabel(period, grouping),
      },
    ).query;
    context.go('/receipts?$query');
  }
}

class CategoryReportsScreen extends ConsumerWidget {
  const CategoryReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptListProvider);
    final categories = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Spending by category')),
      body: SafeArea(
        child: receipts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(receiptListProvider),
              child: const Text('Try again'),
            ),
          ),
          data: (items) {
            final total = items.fold<int>(
              0,
              (sum, item) => sum + item.receipt.totalCents,
            );
            final summaries = _categorySummaries(
              items,
              categories.value ?? const [],
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  '${summaries.where((summary) => summary.count > 0).length} active categories',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  _EmptyReport(onAdd: () => context.push('/receipts/new'))
                else
                  for (final summary in summaries) ...[
                    _CategoryReportTile(
                      summary: summary,
                      overallTotal: total,
                      onTap: () => context.go(
                        '/receipts?category=${Uri.encodeComponent(summary.category.id)}',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

List<_CategorySummary> _categorySummaries(
  List<ReceiptListItem> receipts,
  List<Category> categories,
) {
  final totals = <String, int>{};
  final counts = <String, int>{};
  final categoryMap = <String, Category>{
    for (final category in categories) category.id: category,
  };

  for (final item in receipts) {
    categoryMap[item.category.id] = item.category;
    totals.update(
      item.category.id,
      (value) => value + item.receipt.totalCents,
      ifAbsent: () => item.receipt.totalCents,
    );
    counts.update(item.category.id, (value) => value + 1, ifAbsent: () => 1);
  }

  final summaries = categoryMap.values
      .map(
        (category) => _CategorySummary(
          category: category,
          totalCents: totals[category.id] ?? 0,
          count: counts[category.id] ?? 0,
        ),
      )
      .toList();
  summaries.sort((a, b) {
    final totalComparison = b.totalCents.compareTo(a.totalCents);
    return totalComparison != 0
        ? totalComparison
        : a.category.name.compareTo(b.category.name);
  });
  return summaries;
}

class _OverallTotalCard extends StatelessWidget {
  const _OverallTotalCard({
    required this.totalCents,
    required this.receiptCount,
  });

  final int totalCents;
  final int receiptCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALL TIME · $receiptCount ${receiptCount == 1 ? 'RECEIPT' : 'RECEIPTS'}',
          style: LedgerStyles.eyebrow(context),
        ),
        const SizedBox(height: 14),
        LedgerHeroAmount(cents: totalCents, size: 44),
        const SizedBox(height: 22),
        const LedgerRule(),
      ],
    );
  }
}

class _PeriodSummaryTile extends StatelessWidget {
  const _PeriodSummaryTile({
    required this.period,
    required this.grouping,
    required this.onTap,
  });

  final SpendingPeriodTotal period;
  final SpendingReportGrouping grouping;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(switch (grouping) {
                  SpendingReportGrouping.weekly => Icons.view_week_rounded,
                  SpendingReportGrouping.monthly =>
                    Icons.calendar_month_rounded,
                  SpendingReportGrouping.yearly => Icons.event_rounded,
                }, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _periodLabel(period, grouping),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${period.receiptCount} '
                      '${period.receiptCount == 1 ? 'receipt' : 'receipts'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                ledgerAmount(period.totalCents),
                style: LedgerStyles.rowAmount(context),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateParameter(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _periodLabel(
  SpendingPeriodTotal period,
  SpendingReportGrouping grouping,
) {
  return switch (grouping) {
    SpendingReportGrouping.weekly =>
      '${DateFormat.MMMd().format(period.start)} – '
          '${DateFormat.yMMMd().format(DateTime(period.endExclusive.year, period.endExclusive.month, period.endExclusive.day - 1))}',
    SpendingReportGrouping.monthly => DateFormat.yMMMM().format(period.start),
    SpendingReportGrouping.yearly => DateFormat.y().format(period.start),
  };
}

class _CategoryReportTile extends StatelessWidget {
  const _CategoryReportTile({
    required this.summary,
    required this.overallTotal,
    required this.onTap,
  });

  final _CategorySummary summary;
  final int overallTotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = categoryColor(summary.category, colorScheme);
    final share = overallTotal == 0 ? 0.0 : summary.totalCents / overallTotal;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.13),
                    foregroundColor: color,
                    child: Icon(categoryIcon(summary.category.iconCode)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.category.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${summary.count} '
                          '${summary.count == 1 ? 'receipt' : 'receipts'} · '
                          '${(share * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ledgerAmount(summary.totalCents),
                    style: LedgerStyles.rowAmount(context),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: share.clamp(0, 1),
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.bar_chart_rounded, size: 48),
            const SizedBox(height: 14),
            Text(
              'Reports begin with a receipt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a purchase and its total will appear here immediately.',
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

class _CategorySummary {
  const _CategorySummary({
    required this.category,
    required this.totalCents,
    required this.count,
  });

  final Category category;
  final int totalCents;
  final int count;
}
