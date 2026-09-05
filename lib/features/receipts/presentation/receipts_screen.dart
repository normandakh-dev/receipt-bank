import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/app/theme/ledger_styles.dart';
import 'package:receipt_vault_ai/core/analytics/spending_report_calculator.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/ledger_widgets.dart';

/// "Receipts · Ledger" from the paper-ledger design: mono filter chips and
/// receipts grouped by week with a total in each week header.
class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({
    this.initialCategoryId,
    this.initialStart,
    this.initialEndExclusive,
    this.periodLabel,
    super.key,
  });

  final String? initialCategoryId;
  final DateTime? initialStart;
  final DateTime? initialEndExclusive;
  final String? periodLabel;

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryId;
  bool _starredOnly = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant ReceiptsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategoryId != widget.initialCategoryId) {
      _selectedCategoryId = widget.initialCategoryId;
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(receiptListProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ledger',
                      style: LedgerStyles.screenTitle(context),
                    ),
                  ),
                  IconButton(
                    tooltip: _isSearching ? 'Close search' : 'Search receipts',
                    onPressed: _toggleSearch,
                    icon: Icon(
                      _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add receipt manually',
                    onPressed: () => context.push('/receipts/new'),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search merchant, category, or purpose',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  LedgerChip(
                    label: 'All',
                    selected: _selectedCategoryId == null && !_starredOnly,
                    onTap: () => setState(() {
                      _selectedCategoryId = null;
                      _starredOnly = false;
                    }),
                  ),
                  const SizedBox(width: 7),
                  LedgerChip(
                    label: 'Starred',
                    selected: _starredOnly,
                    onTap: () => setState(() => _starredOnly = !_starredOnly),
                  ),
                  ...categories.when(
                    loading: () => const <Widget>[],
                    error: (error, stackTrace) => const <Widget>[],
                    data: (items) => [
                      for (final category in _ordered(
                        items,
                        receipts.value ?? const [],
                      )) ...[
                        const SizedBox(width: 7),
                        LedgerChip(
                          label: _chipLabel(category),
                          selected: _selectedCategoryId == category.id,
                          onTap: () => setState(() {
                            _selectedCategoryId =
                                _selectedCategoryId == category.id
                                ? null
                                : category.id;
                          }),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (_hasPeriodFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: _PeriodBanner(
                  label: widget.periodLabel ?? 'Selected period',
                  onClear: () => context.go('/receipts'),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: receipts.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: FilledButton(
                    onPressed: () => ref.invalidate(receiptListProvider),
                    child: const Text('Try again'),
                  ),
                ),
                data: (items) {
                  final filtered = _filter(items);
                  if (filtered.isEmpty) {
                    final hasFilters =
                        _selectedCategoryId != null ||
                        _starredOnly ||
                        _hasPeriodFilter ||
                        _searchController.text.trim().isNotEmpty;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                      children: [
                        LedgerEmptyState(
                          title: hasFilters
                              ? 'No matching receipts'
                              : 'No receipts yet',
                          message: hasFilters
                              ? 'Try a different search, category, or period.'
                              : 'Add a receipt to begin your private ledger.',
                          actionLabel: hasFilters ? null : 'Add receipt',
                          onAction: hasFilters
                              ? null
                              : () => context.push('/receipts/new'),
                        ),
                        if (hasFilters)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton(
                              onPressed: () {
                                if (_hasPeriodFilter) {
                                  context.go('/receipts');
                                  return;
                                }
                                _searchController.clear();
                                setState(() {
                                  _selectedCategoryId = null;
                                  _starredOnly = false;
                                });
                              },
                              child: const Text('Clear filters'),
                            ),
                          ),
                      ],
                    );
                  }

                  final groups = _groupByWeek(filtered);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 8 : 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LedgerSectionHeader(
                              label: group.label,
                              underline: true,
                              trailing: Text(
                                ledgerAmount(group.totalCents),
                                style: LedgerStyles.headerAmount(context),
                              ),
                            ),
                            for (final item in group.items)
                              LedgerRow(
                                item: item,
                                onTap: () => context.push(
                                  '/receipts/${item.receipt.id}',
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Selected chip first, then categories by how many receipts use them,
  /// so the filters a person actually needs sit at the front of the row.
  List<Category> _ordered(
    List<Category> items,
    List<ReceiptListItem> receipts,
  ) {
    final counts = <String, int>{};
    for (final item in receipts) {
      counts.update(item.category.id, (value) => value + 1, ifAbsent: () => 1);
    }
    final ordered = [...items]
      ..sort((a, b) {
        if (a.id == _selectedCategoryId) return -1;
        if (b.id == _selectedCategoryId) return 1;
        final byCount = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return ordered;
  }

  static String _chipLabel(Category category) {
    return category.id == LedgerRow.businessCategoryId ? 'Biz' : category.name;
  }

  List<ReceiptListItem> _filter(List<ReceiptListItem> items) {
    final search = _searchController.text.trim().toLowerCase();
    return items
        .where((item) {
          if (_selectedCategoryId != null &&
              item.category.id != _selectedCategoryId) {
            return false;
          }
          if (_starredOnly && !item.receipt.isFavorite) {
            return false;
          }
          final date = item.receipt.transactionDate;
          final matchesStart =
              widget.initialStart == null ||
              !date.isBefore(widget.initialStart!);
          final matchesEnd =
              widget.initialEndExclusive == null ||
              date.isBefore(widget.initialEndExclusive!);
          if (!matchesStart || !matchesEnd) {
            return false;
          }
          if (search.isEmpty) {
            return true;
          }
          return item.receipt.merchantName.toLowerCase().contains(search) ||
              item.category.name.toLowerCase().contains(search) ||
              (item.receipt.purpose?.toLowerCase().contains(search) ?? false) ||
              (item.receipt.notes?.toLowerCase().contains(search) ?? false);
        })
        .toList(growable: false);
  }

  bool get _hasPeriodFilter =>
      widget.initialStart != null && widget.initialEndExclusive != null;

  /// Groups an already date-descending list into weeks starting on Monday.
  static List<_WeekGroup> _groupByWeek(List<ReceiptListItem> items) {
    final now = DateTime.now();
    final thisWeek = SpendingReportCalculator.startOfWeek(now);
    final groups = <_WeekGroup>[];
    for (final item in items) {
      final start = SpendingReportCalculator.startOfWeek(
        item.receipt.transactionDate,
      );
      if (groups.isEmpty || groups.last.start != start) {
        groups.add(
          _WeekGroup(start: start, label: _weekLabel(start, thisWeek)),
        );
      }
      groups.last.items.add(item);
    }
    return groups;
  }

  static String _weekLabel(DateTime start, DateTime thisWeek) {
    if (start == thisWeek) return 'THIS WEEK';
    final end = DateTime(start.year, start.month, start.day + 6);
    final sameMonth = start.month == end.month && start.year == end.year;
    final first = DateFormat('MMM d').format(start);
    final last = sameMonth
        ? DateFormat('d').format(end)
        : DateFormat('MMM d').format(end);
    final suffix = start.year == thisWeek.year ? '' : ' · ${start.year}';
    return '$first – $last$suffix'.toUpperCase();
  }
}

class _WeekGroup {
  _WeekGroup({required this.start, required this.label});

  final DateTime start;
  final String label;
  final List<ReceiptListItem> items = [];

  int get totalCents =>
      items.fold<int>(0, (sum, item) => sum + item.receipt.totalCents);
}

class _PeriodBanner extends StatelessWidget {
  const _PeriodBanner({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: LedgerStyles.accentSoft(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 18,
            color: LedgerStyles.accent(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: LedgerStyles.ink(context),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Clear period',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
