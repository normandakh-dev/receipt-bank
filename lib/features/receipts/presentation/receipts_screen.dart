import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/category_visuals.dart';
import 'package:receipt_vault_ai/shared/widgets/receipt_tile.dart';

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

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(receiptListProvider);
    final categories = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECEIPTS',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Your receipt vault',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/receipts/new'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search merchant, category, or purpose',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: categories.when(
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (items) {
                  final orderedItems = [
                    ...items.where(
                      (category) => category.id == _selectedCategoryId,
                    ),
                    ...items.where(
                      (category) => category.id != _selectedCategoryId,
                    ),
                  ];

                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = null),
                      ),
                      const SizedBox(width: 8),
                      for (final category in orderedItems) ...[
                        ChoiceChip(
                          avatar: Icon(
                            categoryIcon(category.iconCode),
                            size: 18,
                          ),
                          label: Text(category.name),
                          selected: _selectedCategoryId == category.id,
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = category.id),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (_hasPeriodFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.periodLabel ?? 'Selected period',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Clear period',
                        onPressed: () => context.go('/receipts'),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
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
                    return _EmptyReceipts(
                      hasFilters:
                          _selectedCategoryId != null ||
                          _hasPeriodFilter ||
                          _searchController.text.trim().isNotEmpty,
                      onAdd: () => context.push('/receipts/new'),
                      onClear: () {
                        if (_hasPeriodFilter) {
                          context.go('/receipts');
                          return;
                        }
                        _searchController.clear();
                        setState(() => _selectedCategoryId = null);
                      },
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return ReceiptTile(
                        item: item,
                        onTap: () =>
                            context.push('/receipts/${item.receipt.id}'),
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

  List<ReceiptListItem> _filter(List<ReceiptListItem> items) {
    final search = _searchController.text.trim().toLowerCase();
    return items
        .where((item) {
          final matchesCategory =
              _selectedCategoryId == null ||
              item.category.id == _selectedCategoryId;
          if (!matchesCategory) {
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
}

class _EmptyReceipts extends StatelessWidget {
  const _EmptyReceipts({
    required this.hasFilters,
    required this.onAdd,
    required this.onClear,
  });

  final bool hasFilters;
  final VoidCallback onAdd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
        child: Column(
          children: [
            Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              size: 54,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No matching receipts' : 'No receipts yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try a different search or category.'
                  : 'Add a receipt to begin your private spending history.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (hasFilters)
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              )
            else
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
