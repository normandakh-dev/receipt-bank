import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/core/analytics/tax_year_report.dart';
import 'package:receipt_vault_ai/core/export/tax_pdf_export_service.dart';
import 'package:receipt_vault_ai/core/formatters/money_formatter.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:share_plus/share_plus.dart';

class TaxPurposeScreen extends ConsumerStatefulWidget {
  const TaxPurposeScreen({super.key});

  @override
  ConsumerState<TaxPurposeScreen> createState() => _TaxPurposeScreenState();
}

class _TaxPurposeScreenState extends ConsumerState<TaxPurposeScreen> {
  int _selectedYear = DateTime.now().year;
  bool _isPreparingDocument = false;

  Future<void> _emailReport(TaxYearReport report) async {
    setState(() => _isPreparingDocument = true);
    try {
      final file = await TaxPdfExportService.createPdfFile(report);
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Send ${report.year} tax report',
          subject: 'ReceiptVault yearly expenses - ${report.year}',
          text:
              'Attached is my ReceiptVault yearly expense report for '
              '${report.year}.',
          files: [
            XFile(
              file.path,
              mimeType: 'application/pdf',
              name: 'receiptvault-tax-report-${report.year}.pdf',
            ),
          ],
        ),
      );
      if (result.status == ShareResultStatus.unavailable && mounted) {
        _showDocumentError();
      }
    } on Object {
      if (mounted) {
        _showDocumentError();
      }
    } finally {
      if (mounted) {
        setState(() => _isPreparingDocument = false);
      }
    }
  }

  void _showDocumentError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'The tax PDF could not be shared. Check that an email app is '
            'installed and try again.',
          ),
        ),
      );
  }

  void _openMonth(MonthlyTaxExpense month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final label = DateFormat.yMMMM().format(start);
    context.go(
      Uri(
        path: '/receipts',
        queryParameters: {
          'from': start.toIso8601String(),
          'to': end.toIso8601String(),
          'period': label,
        },
      ).toString(),
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
          error: (error, stackTrace) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('The tax report could not be loaded.'),
            ),
          ),
          data: (items) {
            final years = _availableYears(items);
            if (!years.contains(_selectedYear)) {
              _selectedYear = years.first;
            }
            final report = TaxYearReportCalculator.calculate(
              items.map(
                (item) => TaxExpenseRecord(
                  date: item.receipt.transactionDate,
                  totalCents: item.receipt.totalCents,
                  taxCents: item.receipt.taxCents,
                ),
              ),
              _selectedYear,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              children: [
                Text(
                  'TAX PURPOSE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Yearly expenses',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    _YearPicker(
                      years: years,
                      selectedYear: _selectedYear,
                      onChanged: (year) {
                        if (year != null) {
                          setState(() => _selectedYear = year);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Review every month, then create a PDF and choose Gmail or '
                  'another email app to send it.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _YearSummaryCard(report: report),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _isPreparingDocument
                      ? null
                      : () => _emailReport(report),
                  icon: _isPreparingDocument
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(
                    _isPreparingDocument
                        ? 'Creating tax PDF…'
                        : 'Send ${report.year} tax PDF',
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Month by month',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap a month to open its receipts.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final month in report.months) ...[
                  _MonthExpenseCard(
                    month: month,
                    onTap: month.receiptCount == 0
                        ? null
                        : () => _openMonth(month),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.privacy_tip_rounded,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your PDF is prepared on this device and attached '
                            'through Android’s share menu. Choose your email '
                            'app, address it, and press Send.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _YearPicker extends StatelessWidget {
  const _YearPicker({
    required this.years,
    required this.selectedYear,
    required this.onChanged,
  });

  final List<int> years;
  final int selectedYear;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: selectedYear,
      onChanged: onChanged,
      items: [
        for (final year in years)
          DropdownMenuItem(value: year, child: Text(year.toString())),
      ],
    );
  }
}

class _YearSummaryCard extends StatelessWidget {
  const _YearSummaryCard({required this.report});

  final TaxYearReport report;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.year} expense total',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            MoneyFormatter.formatCents(report.totalCents),
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Receipts',
                  value: report.receiptCount.toString(),
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Tax recorded',
                  value: MoneyFormatter.formatCents(report.taxCents),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MonthExpenseCard extends StatelessWidget {
  const _MonthExpenseCard({required this.month, required this.onTap});

  final MonthlyTaxExpense month;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.MMMM().format(
      DateTime(month.year, month.month),
    );
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(DateFormat.MMM().format(DateTime(2024, month.month))),
        ),
        title: Text(monthName),
        subtitle: Text(
          '${month.receiptCount} '
          '${month.receiptCount == 1 ? 'receipt' : 'receipts'}'
          ' · Tax ${MoneyFormatter.formatCents(month.taxCents)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              MoneyFormatter.formatCents(month.totalCents),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

List<int> _availableYears(List<ReceiptListItem> items) {
  final years = <int>{DateTime.now().year};
  for (final item in items) {
    years.add(item.receipt.transactionDate.year);
  }
  final sorted = years.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
}
