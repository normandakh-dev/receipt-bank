import 'package:receipt_vault_ai/core/classification/local_merchant_directory.dart';

class ReceiptOcrParser {
  const ReceiptOcrParser._();

  static final RegExp _amountAtEnd = RegExp(
    r'((?:CAD|USD)?\s*\$?\s*-?[0-9Oo][0-9Oo,\s]*[.,][0-9OoIl]{2})'
    r'(?:\s*(?:CAD|USD))?\s*$',
    caseSensitive: false,
  );
  static final RegExp _amountAnywhere = RegExp(
    r'((?:CAD|USD)?\s*\$?\s*-?[0-9Oo][0-9Oo,\s]*[.,][0-9OoIl]{2})'
    r'(?:\s*(?:CAD|USD))?',
    caseSensitive: false,
  );
  static final RegExp _numericDate = RegExp(
    r'\b(\d{1,4})[-/.](\d{1,2})[-/.](\d{1,4})\b',
  );
  static final RegExp _lastFour = RegExp(
    r'(?:ending|card|acct|account|[*xX•]{2,})[^0-9]{0,8}(\d{4})\b',
    caseSensitive: false,
  );

  static ReceiptScanResult parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final subtotal = _findLabeledAmount(lines, const ['subtotal', 'sub total']);
    final tax = _findTax(lines);
    final tip = _findLabeledAmount(lines, const ['tip', 'gratuity']);
    final labeledTotal = _findLabeledAmount(
      lines,
      const [
        'grand total',
        'amount due',
        'balance due',
        'total due',
        'amount paid',
        'sale total',
        'net total',
        'order total',
        'total',
      ],
      searchSeparatedColumns: true,
      excludedLabels: const [
        'subtotal',
        'sub total',
        'total tax',
        'total items',
        'total discount',
        'total savings',
      ],
    );
    final calculatedTotal = subtotal != null && (tax != null || tip != null)
        ? subtotal + (tax ?? 0) + (tip ?? 0)
        : null;
    final total = labeledTotal ?? calculatedTotal ?? _fallbackTotal(lines);
    final inferredSubtotal =
        subtotal ??
        (total != null
            ? (total - (tax ?? 0) - (tip ?? 0)).clamp(0, total)
            : null);
    final payment = _findPayment(lines);

    return ReceiptScanResult(
      merchantName: _findMerchant(lines),
      transactionDate: _findDate(lines),
      subtotalCents: inferredSubtotal,
      taxCents: tax,
      tipCents: tip,
      totalCents: total,
      paymentMethod: payment.$1,
      cardLastFour: payment.$2,
      items: _findItems(lines, total),
      rawText: rawText.trim(),
    );
  }

  static String _findMerchant(List<String> lines) {
    final localMerchant = LocalMerchantDirectory.match(
      lines.take(8).join('\n'),
    );
    if (localMerchant != null) {
      return localMerchant.canonicalName;
    }

    const rejectedWords = [
      'receipt',
      'invoice',
      'subtotal',
      'total',
      'tax',
      'gst',
      'hst',
      'pst',
      'date',
      'time',
      'cashier',
      'terminal',
      'transaction',
      'customer copy',
      'thank you',
      'welcome',
      'www.',
      'http',
      '@',
      'order number',
      'store number',
      'gst number',
      'business number',
    ];
    final addressPattern = RegExp(
      r'\b(st|street|ave|avenue|road|rd|drive|dr|boulevard|blvd|'
      r'highway|hwy|suite|unit)\b',
      caseSensitive: false,
    );
    final phonePattern = RegExp(r'(?:\+?1[-.\s]?)?\(?\d{3}\)?.*\d{3}.*\d{4}');
    final locationOnlyPattern = RegExp(
      r'^\s*(vancouver|burnaby|richmond|surrey|coquitlam|delta|langley|'
      r'north vancouver|west vancouver)(?:\s*,?\s*(bc|b\.c\.))?\s*$',
      caseSensitive: false,
    );

    for (final line in lines.take(8)) {
      final lower = line.toLowerCase();
      final letterCount = RegExp(r'[A-Za-z]').allMatches(line).length;
      if (line.length < 2 ||
          line.length > 64 ||
          letterCount < 2 ||
          rejectedWords.any(lower.contains) ||
          locationOnlyPattern.hasMatch(line) ||
          addressPattern.hasMatch(line) ||
          phonePattern.hasMatch(line) ||
          _amountAtEnd.hasMatch(line)) {
        continue;
      }
      return _friendlyCase(line);
    }
    return '';
  }

  static DateTime? _findDate(List<String> lines) {
    for (final line in lines) {
      final match = _numericDate.firstMatch(line);
      if (match == null) {
        continue;
      }
      final first = int.tryParse(match.group(1)!);
      final second = int.tryParse(match.group(2)!);
      final third = int.tryParse(match.group(3)!);
      if (first == null || second == null || third == null) {
        continue;
      }

      int year;
      int month;
      int day;
      if (first > 999) {
        year = first;
        month = second;
        day = third;
      } else {
        year = third < 100 ? 2000 + third : third;
        if (first > 12) {
          day = first;
          month = second;
        } else if (second > 12) {
          month = first;
          day = second;
        } else {
          // Most North American receipts use month/day/year.
          month = first;
          day = second;
        }
      }
      final date = _validDate(year, month, day);
      if (date != null) {
        return date;
      }
    }

    const monthNumbers = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final monthFirst = RegExp(
      r'\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|'
      r'May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|'
      r'Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)'
      r'\s+(\d{1,2})(?:st|nd|rd|th)?(?:,\s*|\s+)(\d{4})\b',
      caseSensitive: false,
    );
    final dayFirst = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+'
      r'(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|'
      r'May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|'
      r'Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)'
      r'(?:,\s*|\s+)(\d{4})\b',
      caseSensitive: false,
    );
    for (final line in lines) {
      final firstMatch = monthFirst.firstMatch(line);
      if (firstMatch != null) {
        final month =
            monthNumbers[firstMatch.group(1)!.substring(0, 3).toLowerCase()];
        final day = int.parse(firstMatch.group(2)!);
        final year = int.parse(firstMatch.group(3)!);
        final date = month == null ? null : _validDate(year, month, day);
        if (date != null) {
          return date;
        }
      }
      final secondMatch = dayFirst.firstMatch(line);
      if (secondMatch != null) {
        final day = int.parse(secondMatch.group(1)!);
        final month =
            monthNumbers[secondMatch.group(2)!.substring(0, 3).toLowerCase()];
        final year = int.parse(secondMatch.group(3)!);
        final date = month == null ? null : _validDate(year, month, day);
        if (date != null) {
          return date;
        }
      }
    }
    return null;
  }

  static DateTime? _validDate(int year, int month, int day) {
    if (year < 2000 || year > DateTime.now().year + 1) {
      return null;
    }
    try {
      final date = DateTime(year, month, day);
      return date.year == year && date.month == month && date.day == day
          ? date
          : null;
    } on ArgumentError {
      return null;
    }
  }

  static int? _findLabeledAmount(
    List<String> lines,
    List<String> labels, {
    bool searchSeparatedColumns = false,
    List<String> excludedLabels = const [],
  }) {
    for (var index = lines.length - 1; index >= 0; index--) {
      final line = lines[index];
      final lower = _normalizedLabel(line);
      if (!labels.any(lower.contains) || excludedLabels.any(lower.contains)) {
        continue;
      }
      final amount =
          _parseAmountAtEnd(line) ??
          _parseAmountAnywhere(line) ??
          _parseOcrSeparatedLabeledAmount(line);
      if (amount != null) {
        return amount;
      }
      // Many layouts put the amount directly below a standalone TOTAL label.
      if (index + 1 < lines.length) {
        final followingAmount = _parseStandaloneAmount(lines[index + 1]);
        if (followingAmount != null) return followingAmount;
      }
      // ML Kit can return the left and right columns of a receipt as separate
      // text blocks. In that case labels such as SUBTOTAL and TOTAL appear
      // together, followed later by their standalone amounts.
      if (searchSeparatedColumns) {
        final nearbyAmount = _findNearbyStandaloneAmount(lines, index);
        if (nearbyAmount != null) return nearbyAmount;
      }
    }
    return null;
  }

  static int? _findNearbyStandaloneAmount(List<String> lines, int labelIndex) {
    const maximumDistance = 16;
    final end = (labelIndex + maximumDistance + 1).clamp(0, lines.length);
    final candidates = <int>[];
    for (var index = labelIndex + 2; index < end; index++) {
      final amount = _parseStandaloneAmount(lines[index]);
      if (amount != null && amount > 0) candidates.add(amount);
    }
    if (candidates.isEmpty) return null;

    final frequencies = <int, int>{};
    for (final candidate in candidates) {
      frequencies.update(candidate, (count) => count + 1, ifAbsent: () => 1);
    }
    return frequencies.keys.reduce((best, candidate) {
      final bestCount = frequencies[best]!;
      final candidateCount = frequencies[candidate]!;
      if (candidateCount != bestCount) {
        return candidateCount > bestCount ? candidate : best;
      }
      return candidate > best ? candidate : best;
    });
  }

  static int? _findTax(List<String> lines) {
    final taxAmounts = <int>[];
    for (final line in lines) {
      final lower = _normalizedLabel(line);
      if (!RegExp(r'\b(tax|gst|hst|pst|qst)\b').hasMatch(lower) ||
          lower.contains('taxable')) {
        continue;
      }
      final amount = _parseAmountAtEnd(line);
      if (amount != null && amount >= 0) {
        taxAmounts.add(amount);
      }
    }
    if (taxAmounts.isEmpty) {
      return null;
    }
    return taxAmounts.fold<int>(0, (sum, amount) => sum + amount);
  }

  static int? _fallbackTotal(List<String> lines) {
    const rejectedLabels = [
      'subtotal',
      'sub total',
      'tax',
      'gst',
      'hst',
      'pst',
      'qst',
      'tip',
      'change',
      'cash',
      'tender',
      'saving',
      'discount',
      'reward',
      'points',
      'gift card',
      'coupon',
      'offer',
    ];
    final candidates = <int>[];
    for (final line in lines) {
      final lower = _normalizedLabel(line);
      if (rejectedLabels.any(lower.contains)) continue;
      final amount = _parseAmountAtEnd(line);
      if (amount != null && amount > 0) candidates.add(amount);
    }
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.reduce((a, b) => a > b ? a : b);
  }

  static (String?, String?) _findPayment(List<String> lines) {
    String? method;
    String? lastFour;
    for (final line in lines.reversed) {
      final lower = line.toLowerCase();
      method ??= switch (lower) {
        final value when value.contains('visa') => 'Visa',
        final value when value.contains('mastercard') => 'Mastercard',
        final value when value.contains('master card') => 'Mastercard',
        final value
            when value.contains('amex') || value.contains('american express') =>
          'American Express',
        final value when value.contains('debit') => 'Debit',
        final value when value.contains('cash') => 'Cash',
        _ => null,
      };
      lastFour ??= _lastFour.firstMatch(line)?.group(1);
      if (method != null && lastFour != null) {
        break;
      }
    }
    return (method, lastFour);
  }

  static List<ScannedReceiptItem> _findItems(
    List<String> lines,
    int? totalCents,
  ) {
    const rejectedWords = [
      'subtotal',
      'sub total',
      'total',
      'tax',
      'gst',
      'hst',
      'pst',
      'qst',
      'tip',
      'gratuity',
      'cash',
      'change',
      'tender',
      'visa',
      'mastercard',
      'debit',
      'credit',
      'balance',
      'amount due',
      'saving',
      'discount',
    ];
    final items = <ScannedReceiptItem>[];
    for (final line in lines) {
      final match = _amountAtEnd.firstMatch(line);
      final amount = _parseAmountAtEnd(line);
      if (match == null || amount == null || amount <= 0) {
        continue;
      }
      final name = line.substring(0, match.start).trim();
      final lower = _normalizedLabel(name);
      final letterCount = RegExp(r'[A-Za-z]').allMatches(name).length;
      if (name.length < 2 ||
          letterCount < 2 ||
          rejectedWords.any(lower.contains) ||
          (totalCents != null && amount > totalCents)) {
        continue;
      }
      items.add(
        ScannedReceiptItem(name: _friendlyCase(name), amountCents: amount),
      );
      if (items.length == 20) {
        break;
      }
    }
    return items;
  }

  static int? _parseAmountAtEnd(String line) {
    final match = _amountAtEnd.firstMatch(line);
    if (match == null) {
      return null;
    }
    return _parseAmountToken(match.group(1)!);
  }

  static int? _parseAmountAnywhere(String line) {
    final matches = _amountAnywhere.allMatches(line).toList(growable: false);
    if (matches.isEmpty) return null;
    return _parseAmountToken(matches.last.group(1)!);
  }

  static int? _parseOcrSeparatedLabeledAmount(String line) {
    final match = RegExp(
      r'(?:\$\s*)?([0-9Oo][0-9Oo,]*)\s+([0-9OoIl]{2})(?:\s*(?:CAD|USD))?\s*$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return null;
    final whole = match.group(1)!.replaceAll(',', '');
    return _parseAmountToken('$whole.${match.group(2)}');
  }

  static int? _parseStandaloneAmount(String line) {
    final trimmed = line.trim();
    final amount = _parseAmountAtEnd(trimmed);
    if (amount != null &&
        _amountAtEnd.firstMatch(trimmed)?.group(0)?.trim() == trimmed) {
      return amount;
    }
    final wholeCurrency = RegExp(
      r'^(?:(?:CAD|USD)\s*)?\$\s*([0-9Oo][0-9Oo,]*)(?:\s*(?:CAD|USD))?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (wholeCurrency != null) {
      final whole = wholeCurrency.group(1)!.replaceAll(',', '');
      return _parseAmountToken('$whole.00');
    }
    final separated = RegExp(
      r'^([0-9Oo][0-9Oo,]*)\s+([0-9OoIl]{2})(?:\s*(?:CAD|USD))?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    return separated == null
        ? null
        : _parseAmountToken('${separated.group(1)}.${separated.group(2)}');
  }

  static int? _parseAmountToken(String rawToken) {
    var token = rawToken.toUpperCase();
    token = token
        .replaceAll('CAD', '')
        .replaceAll('USD', '')
        .replaceAll(r'$', '')
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll(' ', '');
    final isNegative = token.startsWith('-');
    token = token.replaceAll('-', '');
    final lastDot = token.lastIndexOf('.');
    final lastComma = token.lastIndexOf(',');
    final decimalIndex = lastDot > lastComma ? lastDot : lastComma;
    if (decimalIndex < 0 || token.length - decimalIndex - 1 != 2) {
      return null;
    }
    final whole = token
        .substring(0, decimalIndex)
        .replaceAll(RegExp(r'[,.]'), '');
    final fraction = token.substring(decimalIndex + 1);
    final cents = int.tryParse('$whole$fraction');
    return cents == null ? null : (isNegative ? -cents : cents);
  }

  static String _friendlyCase(String value) {
    final trimmed = value.trim();
    final letters = trimmed.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty || letters != letters.toUpperCase()) {
      return trimmed;
    }
    return trimmed
        .toLowerCase()
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static String _normalizedLabel(String value) {
    return value.toLowerCase().replaceAll('0', 'o');
  }
}

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.rawText,
    this.merchantName = '',
    this.transactionDate,
    this.subtotalCents,
    this.taxCents,
    this.tipCents,
    this.totalCents,
    this.paymentMethod,
    this.cardLastFour,
    this.items = const [],
    this.sourceImagePath,
  });

  final String rawText;
  final String merchantName;
  final DateTime? transactionDate;
  final int? subtotalCents;
  final int? taxCents;
  final int? tipCents;
  final int? totalCents;
  final String? paymentMethod;
  final String? cardLastFour;
  final List<ScannedReceiptItem> items;
  final String? sourceImagePath;

  ReceiptScanResult withSourceImagePath(String imagePath) {
    return ReceiptScanResult(
      rawText: rawText,
      merchantName: merchantName,
      transactionDate: transactionDate,
      subtotalCents: subtotalCents,
      taxCents: taxCents,
      tipCents: tipCents,
      totalCents: totalCents,
      paymentMethod: paymentMethod,
      cardLastFour: cardLastFour,
      items: items,
      sourceImagePath: imagePath,
    );
  }

  int get detectedFieldCount {
    return [
      merchantName.isNotEmpty,
      transactionDate != null,
      subtotalCents != null,
      taxCents != null,
      totalCents != null,
      paymentMethod != null,
      cardLastFour != null,
    ].where((isDetected) => isDetected).length;
  }
}

class ScannedReceiptItem {
  const ScannedReceiptItem({required this.name, required this.amountCents});

  final String name;
  final int amountCents;
}
