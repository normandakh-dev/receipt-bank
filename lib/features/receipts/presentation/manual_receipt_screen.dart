import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/core/classification/receipt_purpose_classifier.dart';
import 'package:receipt_vault_ai/core/ocr/receipt_ocr_parser.dart';
import 'package:receipt_vault_ai/core/storage/receipt_image_storage.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/category_visuals.dart';

class ManualReceiptScreen extends ConsumerStatefulWidget {
  const ManualReceiptScreen({
    this.scannedReceipt,
    this.existingReceipt,
    super.key,
  });

  final ReceiptScanResult? scannedReceipt;
  final ReceiptDetails? existingReceipt;

  @override
  ConsumerState<ManualReceiptScreen> createState() =>
      _ManualReceiptScreenState();
}

class _ManualReceiptScreenState extends ConsumerState<ManualReceiptScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _subtotalController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _tipController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _lastFourController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final List<String> _classificationItemNames = [];
  final List<_EditableReceiptItem> _items = [];

  DateTime? _transactionDate;
  bool _showDateError = false;
  ReceiptClassification _classification = ReceiptPurposeClassifier.classify(
    merchantName: '',
  );
  String? _lastSuggestedPurpose;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReceipt;
    final scannedReceipt = widget.scannedReceipt;
    if (existing != null) {
      final receipt = existing.receipt;
      _merchantController.text = receipt.merchantName;
      _subtotalController.text = _formatEditableMoney(receipt.subtotalCents);
      _taxController.text = _formatEditableMoney(receipt.taxCents);
      _tipController.text = _formatEditableMoney(receipt.tipCents);
      _totalController.text = _formatEditableMoney(receipt.totalCents);
      _paymentController.text = receipt.paymentMethod ?? '';
      _lastFourController.text = receipt.cardLastFour ?? '';
      _notesController.text = receipt.notes ?? '';
      _purposeController.text = receipt.purpose ?? '';
      _transactionDate = receipt.transactionDate;
      for (final item in existing.items) {
        _items.add(_EditableReceiptItem(item.name, item.totalPriceCents));
        _classificationItemNames.add(item.name);
      }
      _classification = ReceiptPurposeClassifier.classify(
        merchantName: receipt.merchantName,
        itemNames: _classificationItemNames,
      );
    } else if (scannedReceipt != null) {
      _merchantController.text = scannedReceipt.merchantName;
      _subtotalController.text = _formatEditableMoney(
        scannedReceipt.subtotalCents,
      );
      _taxController.text = _formatEditableMoney(scannedReceipt.taxCents);
      _tipController.text = _formatEditableMoney(scannedReceipt.tipCents);
      _totalController.text = _formatEditableMoney(scannedReceipt.totalCents);
      _paymentController.text = scannedReceipt.paymentMethod ?? '';
      _lastFourController.text = scannedReceipt.cardLastFour ?? '';
      final scannedDate = scannedReceipt.transactionDate;
      if (scannedDate != null &&
          !scannedDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
        _transactionDate = scannedDate;
      }
      _classificationItemNames.addAll(
        scannedReceipt.items.map((item) => item.name),
      );
      for (final item in scannedReceipt.items) {
        _items.add(_EditableReceiptItem(item.name, item.amountCents));
      }
      _classification = ReceiptPurposeClassifier.classify(
        merchantName: _merchantController.text,
        itemNames: _classificationItemNames,
      );
      _purposeController.text = _classification.purpose;
      _lastSuggestedPurpose = _classification.purpose;
    }
    _merchantController.addListener(_refreshClassification);
  }

  @override
  void dispose() {
    _merchantController
      ..removeListener(_refreshClassification)
      ..dispose();
    _subtotalController.dispose();
    _taxController.dispose();
    _tipController.dispose();
    _totalController.dispose();
    _paymentController.dispose();
    _lastFourController.dispose();
    _notesController.dispose();
    _purposeController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _refreshClassification() {
    final classification = ReceiptPurposeClassifier.classify(
      merchantName: _merchantController.text,
      itemNames: _classificationItemNames,
    );
    final shouldUpdatePurpose =
        _purposeController.text.trim().isEmpty ||
        _purposeController.text == _lastSuggestedPurpose;
    if (shouldUpdatePurpose) {
      _purposeController.text = classification.purpose;
      _lastSuggestedPurpose = classification.purpose;
    }
    if (mounted) {
      setState(() => _classification = classification);
    }
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _transactionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null) {
      setState(() {
        _transactionDate = selected;
        _showDateError = false;
      });
    }
  }

  Future<void> _showRecognizedText() {
    final rawText = widget.scannedReceipt?.rawText ?? '';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recognized receipt text'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(rawText)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmReplaceDuplicate(Receipt duplicate) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.content_copy_rounded),
        title: const Text('Duplicate receipt'),
        content: Text(
          'A receipt from ${duplicate.merchantName} on '
          '${DateFormat.yMMMMd().format(duplicate.transactionDate)} for '
          '${NumberFormat.simpleCurrency(name: duplicate.currencyCode).format(duplicate.totalCents / 100)} '
          'is already saved. Replace the existing receipt?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep existing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace existing'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_transactionDate == null) {
      setState(() => _showDateError = true);
      return;
    }

    FocusScope.of(context).unfocus();
    final database = ref.read(databaseProvider);
    final totalCents = _parseMoney(_totalController.text)!;
    final duplicate = await database.findDuplicateReceipt(
      merchantName: _merchantController.text,
      transactionDate: _transactionDate!,
      totalCents: totalCents,
      excludingReceiptId: widget.existingReceipt?.receipt.id,
    );
    if (!mounted) return;
    if (duplicate != null && widget.existingReceipt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Those details match another saved receipt.'),
        ),
      );
      return;
    }
    if (duplicate != null && !await _confirmReplaceDuplicate(duplicate)) {
      return;
    }
    if (!mounted) return;

    final categories = await database.getCategories();
    if (!mounted) {
      return;
    }

    final categoryId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CategoryPicker(
        categories: categories,
        suggestedCategoryId:
            widget.existingReceipt?.category.id ?? _classification.categoryId,
        suggestionReason: _classification.reason,
      ),
    );
    if (categoryId == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    String? storedImagePath;
    try {
      storedImagePath = await ReceiptImageStorage.persist(
        widget.scannedReceipt?.sourceImagePath,
      );
      final draft = ReceiptDraft(
        merchantName: _merchantController.text,
        transactionDate: _transactionDate!,
        categoryId: categoryId,
        subtotalCents: _parseMoney(_subtotalController.text) ?? 0,
        taxCents: _parseMoney(_taxController.text) ?? 0,
        tipCents: _parseMoney(_tipController.text) ?? 0,
        totalCents: totalCents,
        paymentMethod: _paymentController.text,
        cardLastFour: _lastFourController.text,
        notes: _notesController.text,
        purpose: _purposeController.text,
        imagePath: storedImagePath,
        rawOcrText: widget.scannedReceipt?.rawText,
        items: _items
            .where((item) => item.name.text.trim().isNotEmpty)
            .map((item) {
              final cents = _parseMoney(item.amount.text) ?? 0;
              return ReceiptItemDraft(
                name: item.name.text,
                quantity: 1,
                unitPriceCents: cents,
                totalPriceCents: cents,
              );
            })
            .toList(growable: false),
      );
      final existingId = widget.existingReceipt?.receipt.id;
      final receiptId =
          existingId ?? duplicate?.id ?? await database.createReceipt(draft);
      if (existingId != null || duplicate != null) {
        await database.replaceReceipt(receiptId, draft);
      }

      if (mounted) {
        context.go('/receipts/$receiptId');
      }
    } on Object {
      await ReceiptImageStorage.deleteOwnedImage(storedImagePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The receipt could not be saved. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingReceipt != null
              ? 'Edit receipt'
              : widget.scannedReceipt == null
              ? 'Add receipt'
              : 'Review scan',
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
          children: [
            Text(
              widget.scannedReceipt == null
                  ? 'RECEIPT DETAILS'
                  : 'SCANNED RECEIPT',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.scannedReceipt == null
                  ? 'Enter what you know'
                  : 'Check what was detected',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.scannedReceipt == null
                  ? 'ReceiptVault will suggest the purpose and category. You '
                        'will confirm the category before anything is saved.'
                  : 'OCR has prefilled the fields below. Correct anything that '
                        'looks wrong, then confirm the category before saving.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.scannedReceipt case final scan?) ...[
              const SizedBox(height: 16),
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fact_check_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${scan.detectedFieldCount} receipt field groups '
                          'detected on-device',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: colorScheme.onPrimaryContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: _showRecognizedText,
                        child: const Text('View text'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _merchantController,
                      autofocus: widget.scannedReceipt == null,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Merchant',
                        hintText: 'e.g. Loblaws or Shell',
                        prefixIcon: Icon(Icons.storefront_rounded),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter the merchant name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(16),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Purchase date',
                          prefixIcon: const Icon(Icons.calendar_today_rounded),
                          errorText: _showDateError
                              ? 'Choose the purchase date'
                              : null,
                        ),
                        child: Text(
                          _transactionDate == null
                              ? 'Select purchase date'
                              : DateFormat.yMMMMd().format(_transactionDate!),
                          style: _transactionDate == null
                              ? TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _PurposeSuggestionCard(
              classification: _classification,
              purposeController: _purposeController,
            ),
            const SizedBox(height: 14),
            _LineItemsCard(
              items: _items,
              onAdd: () =>
                  setState(() => _items.add(_EditableReceiptItem('', 0))),
              onRemove: (index) => setState(() {
                _items.removeAt(index).dispose();
              }),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amounts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _MoneyField(
                            controller: _subtotalController,
                            label: 'Subtotal',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MoneyField(
                            controller: _taxController,
                            label: 'Tax',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MoneyField(
                            controller: _tipController,
                            label: 'Tip',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MoneyField(
                            controller: _totalController,
                            label: 'Total *',
                            validator: (value) {
                              final cents = _parseMoney(value ?? '');
                              return cents == null || cents <= 0
                                  ? 'Enter total'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment and notes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _paymentController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Payment method',
                        hintText: 'Visa, debit, cash…',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastFourController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Card last 4 digits',
                        prefixIcon: Icon(Icons.pin_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        return text.isNotEmpty && text.length != 4
                            ? 'Enter 4 digits'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Optional reminder or context',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _isSaving
                    ? 'Saving…'
                    : widget.existingReceipt == null
                    ? 'Choose category and save'
                    : 'Choose category and update',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptEditScreen extends ConsumerWidget {
  const ReceiptEditScreen({required this.receiptId, super.key});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(receiptDetailsProvider(receiptId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => const Scaffold(
            body: Center(child: Text('This receipt could not be loaded.')),
          ),
          data: (details) => details == null
              ? const Scaffold(
                  body: Center(child: Text('This receipt no longer exists.')),
                )
              : ManualReceiptScreen(existingReceipt: details),
        );
  }
}

class _EditableReceiptItem {
  _EditableReceiptItem(String itemName, int amountCents)
    : name = TextEditingController(text: itemName),
      amount = TextEditingController(text: _formatEditableMoney(amountCents));

  final TextEditingController name;
  final TextEditingController amount;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _LineItemsCard extends StatelessWidget {
  const _LineItemsCard({
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_EditableReceiptItem> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Line items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
          if (items.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No individual items detected.'),
            ),
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: items[index].name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Item'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MoneyField(
                    controller: items[index].amount,
                    label: 'Amount',
                  ),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _PurposeSuggestionCard extends StatelessWidget {
  const _PurposeSuggestionCard({
    required this.classification,
    required this.purposeController,
  });

  final ReceiptClassification classification;
  final TextEditingController purposeController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline purpose suggestion',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        classification.reason,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: purposeController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Purchase purpose',
                prefixIcon: Icon(Icons.flag_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label, prefixText: r'$ '),
      validator: validator,
    );
  }
}

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({
    required this.categories,
    required this.suggestedCategoryId,
    required this.suggestionReason,
  });

  final List<Category> categories;
  final String suggestedCategoryId;
  final String suggestionReason;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  late String _selectedId = widget.suggestedCategoryId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.76,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 18),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Which category should save this receipt?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Suggested automatically · ${widget.suggestionReason}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final category = widget.categories[index];
                  final isSelected = category.id == _selectedId;
                  final isSuggested = category.id == widget.suggestedCategoryId;
                  final color = categoryColor(category, colorScheme);
                  return Card(
                    color: isSelected ? color.withValues(alpha: 0.12) : null,
                    child: ListTile(
                      onTap: () => setState(() => _selectedId = category.id),
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.14),
                        foregroundColor: color,
                        child: Icon(categoryIcon(category.iconCode)),
                      ),
                      title: Text(category.name),
                      subtitle: isSuggested
                          ? const Text('ReceiptVault suggestion')
                          : null,
                      trailing: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selectedId),
                child: const Text('Save in selected category'),
              ),
            ),
          ],
        );
      },
    );
  }
}

int? _parseMoney(String input) {
  final normalized = input
      .replaceAll(',', '')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  final value = double.tryParse(normalized);
  return value == null ? null : (value * 100).round();
}

String _formatEditableMoney(int? cents) {
  return cents == null ? '' : (cents / 100).toStringAsFixed(2);
}
