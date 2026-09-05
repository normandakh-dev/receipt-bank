import 'package:receipt_vault_ai/core/classification/local_merchant_directory.dart';

class ReceiptClassification {
  const ReceiptClassification({
    required this.categoryId,
    required this.purpose,
    required this.reason,
    required this.confidence,
  });

  final String categoryId;
  final String purpose;
  final String reason;
  final double confidence;
}

abstract final class ReceiptPurposeClassifier {
  static const List<_Rule> _rules = [
    _Rule(
      categoryId: 'category-groceries',
      purpose: 'Groceries and household essentials',
      keywords: [
        'grocery',
        'groceries',
        'supermarket',
        'loblaws',
        'save on foods',
        'walmart',
        'costco',
        'safeway',
        'whole foods',
        'produce',
        'milk',
        'bakery',
        'market',
        'foods',
        'butcher',
        'deli',
      ],
    ),
    _Rule(
      categoryId: 'category-restaurants',
      purpose: 'Dining and meals',
      keywords: [
        'restaurant',
        'cafe',
        'coffee',
        'pizza',
        'burger',
        'sushi',
        'grill',
        'kitchen',
        'starbucks',
        'tim hortons',
        'mcdonald',
        'bakery',
        'ramen',
        'noodle',
        'bistro',
        'brunch',
        'tacos',
        'pho',
        'pub',
      ],
    ),
    _Rule(
      categoryId: 'category-gas',
      purpose: 'Fuel and vehicle travel',
      keywords: ['gas', 'fuel', 'petro', 'shell', 'chevron', 'esso', 'husky'],
    ),
    _Rule(
      categoryId: 'category-transportation',
      purpose: 'Local transportation',
      keywords: [
        'transit',
        'translink',
        'uber',
        'lyft',
        'taxi',
        'parking',
        'bus',
        'train',
      ],
    ),
    _Rule(
      categoryId: 'category-utilities',
      purpose: 'Household utilities and services',
      keywords: [
        'hydro',
        'electric',
        'utility',
        'internet',
        'telus',
        'rogers',
        'shaw',
        'water bill',
        'phone bill',
      ],
    ),
    _Rule(
      categoryId: 'category-entertainment',
      purpose: 'Entertainment and recreation',
      keywords: [
        'cinema',
        'cineplex',
        'movie',
        'theatre',
        'concert',
        'netflix',
        'spotify',
        'game',
      ],
    ),
    _Rule(
      categoryId: 'category-health',
      purpose: 'Health and personal care',
      keywords: [
        'pharmacy',
        'drug mart',
        'clinic',
        'dental',
        'doctor',
        'medicine',
        'prescription',
        'optical',
        'wellness',
        'physio',
        'optometry',
      ],
    ),
    _Rule(
      categoryId: 'category-travel',
      purpose: 'Travel and accommodation',
      keywords: [
        'air canada',
        'westjet',
        'airline',
        'flight',
        'hotel',
        'airbnb',
        'resort',
        'booking',
      ],
    ),
    _Rule(
      categoryId: 'category-business',
      purpose: 'Business or work expense',
      keywords: [
        'staples',
        'office',
        'business',
        'software',
        'subscription',
        'conference',
        'coworking',
      ],
    ),
    _Rule(
      categoryId: 'category-education',
      purpose: 'Education and learning',
      keywords: [
        'school',
        'college',
        'university',
        'tuition',
        'course',
        'textbook',
        'udemy',
      ],
    ),
    _Rule(
      categoryId: 'category-home',
      purpose: 'Home maintenance and furnishings',
      keywords: [
        'home depot',
        'hardware',
        'furniture',
        'ikea',
        'rona',
        'lowes',
        'plumbing',
        'paint',
      ],
    ),
    _Rule(
      categoryId: 'category-shopping',
      purpose: 'General shopping',
      keywords: [
        'amazon',
        'mall',
        'clothing',
        'shoes',
        'electronics',
        'best buy',
        'department store',
        'boutique',
        'apparel',
        'sportswear',
      ],
    ),
  ];

  static ReceiptClassification classify({
    required String merchantName,
    Iterable<String> itemNames = const [],
  }) {
    final merchant = merchantName.trim().toLowerCase();
    final items = itemNames.join(' ').toLowerCase();
    final localMerchant = LocalMerchantDirectory.match(merchantName);
    if (localMerchant != null) {
      return ReceiptClassification(
        categoryId: localMerchant.categoryId,
        purpose: localMerchant.purpose,
        reason: 'Recognized ${localMerchant.canonicalName}',
        confidence: 0.96,
      );
    }
    _Rule? bestRule;
    var bestScore = 0;
    String? matchedKeyword;

    for (final rule in _rules) {
      var score = 0;
      String? ruleMatch;
      for (final keyword in rule.keywords) {
        final pattern = _keywordPattern(keyword);
        if (pattern.hasMatch(merchant)) {
          score += 3;
          ruleMatch ??= keyword;
        }
        if (pattern.hasMatch(items)) {
          score += 1;
          ruleMatch ??= keyword;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestRule = rule;
        matchedKeyword = ruleMatch;
      }
    }

    if (bestRule == null) {
      return const ReceiptClassification(
        categoryId: 'category-other',
        purpose: 'General purchase',
        reason: 'No strong match yet',
        confidence: 0.2,
      );
    }

    return ReceiptClassification(
      categoryId: bestRule.categoryId,
      purpose: bestRule.purpose,
      reason: 'Matched “$matchedKeyword”',
      confidence: bestScore >= 3 ? 0.9 : 0.65,
    );
  }

  static final Map<String, RegExp> _patternCache = {};

  /// Keywords must match whole words. A plain substring test lets "bus"
  /// match "business" and "gas" match "Las Vegas", which mis-files receipts.
  static RegExp _keywordPattern(String keyword) {
    return _patternCache.putIfAbsent(
      keyword,
      () => RegExp(r'\b' + RegExp.escape(keyword) + r'\b'),
    );
  }
}

class _Rule {
  const _Rule({
    required this.categoryId,
    required this.purpose,
    required this.keywords,
  });

  final String categoryId;
  final String purpose;
  final List<String> keywords;
}
