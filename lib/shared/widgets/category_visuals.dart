import 'package:flutter/material.dart';
import 'package:receipt_vault_ai/data/local/app_database.dart';

IconData categoryIcon(String iconCode) {
  return switch (iconCode) {
    'shopping_basket' => Icons.shopping_basket_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'local_gas_station' => Icons.local_gas_station_rounded,
    'directions_transit' => Icons.directions_transit_rounded,
    'shopping_bag' => Icons.shopping_bag_rounded,
    'bolt' => Icons.bolt_rounded,
    'movie' => Icons.movie_rounded,
    'health_and_safety' => Icons.health_and_safety_rounded,
    'flight' => Icons.flight_rounded,
    'business_center' => Icons.business_center_rounded,
    'school' => Icons.school_rounded,
    'home' => Icons.home_rounded,
    'label' => Icons.label_rounded,
    _ => Icons.category_rounded,
  };
}

Color categoryColor(Category category, ColorScheme colorScheme) {
  return category.colorValue == null
      ? colorScheme.primary
      : Color(category.colorValue!);
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    required this.category,
    this.compact = false,
    super.key,
  });

  final Category category;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category, Theme.of(context).colorScheme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            categoryIcon(category.iconCode),
            size: compact ? 14 : 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            category.name,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
