import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';
import 'package:receipt_vault_ai/data/providers/database_providers.dart';
import 'package:receipt_vault_ai/shared/widgets/category_visuals.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<String?> _askForName(
    BuildContext context, {
    String? initialName,
  }) async {
    final controller = TextEditingController(text: initialName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initialName == null ? 'Create a category' : 'Edit category',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Pets',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(initialName == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  Future<void> _createCategory(BuildContext context, WidgetRef ref) async {
    final name = await _askForName(context);
    if (name == null || !context.mounted) return;
    try {
      await ref.read(databaseProvider).createCategory(name);
      if (context.mounted) {
        _showMessage(context, 'Created “$name”.');
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'That category already exists or is not valid.');
      }
    }
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final name = await _askForName(context, initialName: category.name);
    if (name == null || name == category.name || !context.mounted) return;
    try {
      await ref.read(databaseProvider).updateCategoryName(category.id, name);
      if (context.mounted) {
        _showMessage(context, 'Updated category to “$name”.');
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'That category name is already in use.');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCategory(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.insights_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Looking for category totals?',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'To check a category report, go to Reports. This '
                            'page is for adding and editing categories.',
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => context.go('/reports'),
                            icon: const Icon(Icons.bar_chart_rounded),
                            label: const Text('Go to Reports'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All categories',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            categories.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Categories could not be loaded.'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(categoriesProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) => Column(
                children: [
                  for (final category in items) ...[
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: categoryColor(
                            category,
                            colorScheme,
                          ).withValues(alpha: 0.14),
                          child: Icon(
                            categoryIcon(category.iconCode),
                            color: categoryColor(category, colorScheme),
                          ),
                        ),
                        title: Text(category.name),
                        subtitle: Text(
                          category.isDefault
                              ? 'Default category'
                              : 'Custom category',
                        ),
                        trailing: IconButton(
                          tooltip: 'Edit ${category.name}',
                          onPressed: () =>
                              _editCategory(context, ref, category),
                          icon: const Icon(Icons.edit_rounded),
                        ),
                        onTap: () => _editCategory(context, ref, category),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
