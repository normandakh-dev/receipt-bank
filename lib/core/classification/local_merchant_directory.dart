class LocalMerchantProfile {
  const LocalMerchantProfile({
    required this.canonicalName,
    required this.categoryId,
    required this.purpose,
    required this.aliases,
  });

  final String canonicalName;
  final String categoryId;
  final String purpose;
  final List<String> aliases;
}

/// Common merchants seen on receipts around Vancouver and Metro Vancouver.
/// Matching happens entirely on-device and accepts common OCR/header variants.
abstract final class LocalMerchantDirectory {
  static const List<LocalMerchantProfile> profiles = [
    LocalMerchantProfile(
      canonicalName: 'Save-On-Foods',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['save on foods', 'saveonfoods'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Urban Fare',
      categoryId: 'category-groceries',
      purpose: 'Groceries and prepared food',
      aliases: ['urban fare'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Nesters Market',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['nesters market', 'nesters food market'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Choices Markets',
      categoryId: 'category-groceries',
      purpose: 'Groceries and natural foods',
      aliases: ['choices markets', 'choices market'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Meinhardt Fine Foods',
      categoryId: 'category-groceries',
      purpose: 'Groceries and prepared food',
      aliases: ['meinhardt fine foods', 'meinhardt'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Buy-Low Foods',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['buy low foods', 'buy-low foods', 'buylow foods'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Fresh St. Market',
      categoryId: 'category-groceries',
      purpose: 'Groceries and fresh food',
      aliases: ['fresh st market', 'fresh street market'],
    ),
    LocalMerchantProfile(
      canonicalName: 'T&T Supermarket',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['t&t supermarket', 't & t supermarket', 't and t supermarket'],
    ),
    LocalMerchantProfile(
      canonicalName: 'H Mart',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['h mart', 'hmart'],
    ),
    LocalMerchantProfile(
      canonicalName: "Kin's Farm Market",
      categoryId: 'category-groceries',
      purpose: 'Fresh produce and groceries',
      aliases: ['kins farm market', "kin's farm market"],
    ),
    LocalMerchantProfile(
      canonicalName: 'Loblaws City Market',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['loblaws city market', 'city market'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Real Canadian Superstore',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['real canadian superstore', 'superstore'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Whole Foods Market',
      categoryId: 'category-groceries',
      purpose: 'Groceries and prepared food',
      aliases: ['whole foods market', 'whole foods'],
    ),
    LocalMerchantProfile(
      canonicalName: 'No Frills',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['no frills', 'nofrills'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Safeway',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['safeway'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Costco Wholesale',
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      aliases: ['costco wholesale', 'costco'],
    ),
    LocalMerchantProfile(
      canonicalName: 'London Drugs',
      categoryId: 'category-health',
      purpose: 'Health, personal care, and household supplies',
      aliases: ['london drugs', 'london drug'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Shoppers Drug Mart',
      categoryId: 'category-health',
      purpose: 'Health and personal care',
      aliases: ['shoppers drug mart', 'shoppersdrugmart'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Pharmasave',
      categoryId: 'category-health',
      purpose: 'Health and personal care',
      aliases: ['pharmasave'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Rexall',
      categoryId: 'category-health',
      purpose: 'Health and personal care',
      aliases: ['rexall'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Breka Bakery & Cafe',
      categoryId: 'category-restaurants',
      purpose: 'Cafe, bakery, and prepared food',
      aliases: ['breka bakery cafe', 'breka bakery & cafe', 'breka'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Cactus Club Cafe',
      categoryId: 'category-restaurants',
      purpose: 'Dining and meals',
      aliases: ['cactus club cafe', 'cactus club'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Earls Kitchen + Bar',
      categoryId: 'category-restaurants',
      purpose: 'Dining and meals',
      aliases: ['earls kitchen bar', 'earls restaurant', 'earls'],
    ),
    LocalMerchantProfile(
      canonicalName: 'White Spot',
      categoryId: 'category-restaurants',
      purpose: 'Dining and meals',
      aliases: ['white spot'],
    ),
    LocalMerchantProfile(
      canonicalName: 'JAPADOG',
      categoryId: 'category-restaurants',
      purpose: 'Dining and meals',
      aliases: ['japadog', 'japa dog'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Freshslice Pizza',
      categoryId: 'category-restaurants',
      purpose: 'Dining and meals',
      aliases: ['freshslice pizza', 'fresh slice pizza', 'freshslice'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Browns Socialhouse',
      categoryId: 'category-restaurants',
      purpose: 'Dining and meals',
      aliases: ['browns socialhouse', 'browns social house'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Cafe Medina',
      categoryId: 'category-restaurants',
      purpose: 'Cafe and dining',
      aliases: ['cafe medina', 'café medina'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Joe Fortes',
      categoryId: 'category-restaurants',
      purpose: 'Dining and meals',
      aliases: ['joe fortes seafood chophouse', 'joe fortes'],
    ),
    LocalMerchantProfile(
      canonicalName: 'TransLink',
      categoryId: 'category-transportation',
      purpose: 'Public transit fare',
      aliases: ['translink', 'compass card', 'compass vending'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Evo Car Share',
      categoryId: 'category-transportation',
      purpose: 'Car-share transportation',
      aliases: ['evo car share', 'evo carshare', 'evo mobility'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Modo',
      categoryId: 'category-transportation',
      purpose: 'Car-share transportation',
      aliases: ['modo car share', 'modo carshare'],
    ),
    LocalMerchantProfile(
      canonicalName: 'EasyPark',
      categoryId: 'category-transportation',
      purpose: 'Parking',
      aliases: ['easypark', 'easy park'],
    ),
    LocalMerchantProfile(
      canonicalName: 'BC Hydro',
      categoryId: 'category-utilities',
      purpose: 'Household electricity',
      aliases: ['bc hydro', 'b c hydro'],
    ),
    LocalMerchantProfile(
      canonicalName: 'BC Ferries',
      categoryId: 'category-travel',
      purpose: 'Ferry travel',
      aliases: ['bc ferries', 'b c ferries'],
    ),
    LocalMerchantProfile(
      canonicalName: 'BC Liquor Stores',
      categoryId: 'category-shopping',
      purpose: 'Beverages and general shopping',
      aliases: ['bc liquor stores', 'bcliquor', 'b c liquor'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Canadian Tire',
      categoryId: 'category-home',
      purpose: 'Home, hardware, and vehicle supplies',
      aliases: ['canadian tire', 'cdn tire'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Aritzia',
      categoryId: 'category-shopping',
      purpose: 'Clothing and accessories',
      aliases: ['aritzia', 'wilfred'],
    ),
    LocalMerchantProfile(
      canonicalName: 'lululemon',
      categoryId: 'category-shopping',
      purpose: 'Clothing and accessories',
      aliases: ['lululemon', 'lulu lemon'],
    ),
    LocalMerchantProfile(
      canonicalName: "Arc'teryx",
      categoryId: 'category-shopping',
      purpose: 'Outdoor clothing and equipment',
      aliases: ["arc'teryx", 'arcteryx', 'arc teryx'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Cineplex',
      categoryId: 'category-entertainment',
      purpose: 'Movies and entertainment',
      aliases: ['cineplex', 'scotiabank theatre'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Science World',
      categoryId: 'category-entertainment',
      purpose: 'Attraction and recreation',
      aliases: ['science world'],
    ),
    LocalMerchantProfile(
      canonicalName: 'Vancouver Aquarium',
      categoryId: 'category-entertainment',
      purpose: 'Attraction and recreation',
      aliases: ['vancouver aquarium'],
    ),
  ];

  static LocalMerchantProfile? match(String text) {
    final normalizedText = ' ${_normalize(text)} ';
    if (normalizedText.trim().isEmpty) return null;
    for (final profile in profiles) {
      for (final alias in profile.aliases) {
        final normalizedAlias = _normalize(alias);
        if (normalizedAlias.isNotEmpty &&
            normalizedText.contains(' $normalizedAlias ')) {
          return profile;
        }
      }
    }
    return null;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
