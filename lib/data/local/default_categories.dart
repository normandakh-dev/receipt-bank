class DefaultCategoryDefinition {
  const DefaultCategoryDefinition({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
  });

  final String id;
  final String name;
  final String iconCode;
  final int colorValue;
}

abstract final class DefaultCategories {
  static const List<DefaultCategoryDefinition> values = [
    DefaultCategoryDefinition(
      id: 'category-groceries',
      name: 'Groceries',
      iconCode: 'shopping_basket',
      colorValue: 0xFF43A047,
    ),
    DefaultCategoryDefinition(
      id: 'category-restaurants',
      name: 'Restaurants',
      iconCode: 'restaurant',
      colorValue: 0xFFFF7043,
    ),
    DefaultCategoryDefinition(
      id: 'category-gas',
      name: 'Gas',
      iconCode: 'local_gas_station',
      colorValue: 0xFF5C6BC0,
    ),
    DefaultCategoryDefinition(
      id: 'category-transportation',
      name: 'Transportation',
      iconCode: 'directions_transit',
      colorValue: 0xFF26A69A,
    ),
    DefaultCategoryDefinition(
      id: 'category-shopping',
      name: 'Shopping',
      iconCode: 'shopping_bag',
      colorValue: 0xFFAB47BC,
    ),
    DefaultCategoryDefinition(
      id: 'category-utilities',
      name: 'Utilities',
      iconCode: 'bolt',
      colorValue: 0xFFFFA726,
    ),
    DefaultCategoryDefinition(
      id: 'category-entertainment',
      name: 'Entertainment',
      iconCode: 'movie',
      colorValue: 0xFFEC407A,
    ),
    DefaultCategoryDefinition(
      id: 'category-health',
      name: 'Health',
      iconCode: 'health_and_safety',
      colorValue: 0xFFEF5350,
    ),
    DefaultCategoryDefinition(
      id: 'category-travel',
      name: 'Travel',
      iconCode: 'flight',
      colorValue: 0xFF29B6F6,
    ),
    DefaultCategoryDefinition(
      id: 'category-business',
      name: 'Business',
      iconCode: 'business_center',
      colorValue: 0xFF78909C,
    ),
    DefaultCategoryDefinition(
      id: 'category-education',
      name: 'Education',
      iconCode: 'school',
      colorValue: 0xFF7E57C2,
    ),
    DefaultCategoryDefinition(
      id: 'category-home',
      name: 'Home',
      iconCode: 'home',
      colorValue: 0xFF8D6E63,
    ),
    DefaultCategoryDefinition(
      id: 'category-other',
      name: 'Other',
      iconCode: 'category',
      colorValue: 0xFF90A4AE,
    ),
  ];
}
