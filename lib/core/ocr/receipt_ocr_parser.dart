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
    r'(?:ending|card|acct|account|[*xX•]{2,}|\.{2,}|…)[^0-9]{0,8}(\d{4})\b',
    caseSensitive: false,
  );

  /// Parses recognised receipt text. [now] anchors date disambiguation and
  /// future-date rejection; it defaults to the current time.
  static ReceiptScanResult parse(String rawText, {DateTime? now}) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map(_normalizeOcrLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final subtotal = _findLabeledAmount(lines, const ['subtotal', 'sub total']);
    var tax = _findTax(lines);
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
    // The printed total is the most reliable number on a receipt. When both
    // it and the subtotal were read but the tax lines do not add up (a lost
    // PST line, a cents column dropped by OCR), take the tax the arithmetic
    // implies so the prefilled amounts are at least consistent.
    if (labeledTotal != null && subtotal != null) {
      final derivedTax = labeledTotal - subtotal - (tip ?? 0);
      final booksBalance = subtotal + (tax ?? 0) + (tip ?? 0) == labeledTotal;
      if (!booksBalance && derivedTax > 0 && derivedTax <= subtotal * 0.3) {
        tax = derivedTax;
      }
    }
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
      transactionDate: _findDate(lines, now ?? DateTime.now()),
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

  /// Collapses whitespace and repairs the decimal artefacts ML Kit produces
  /// on receipt columns: "50. .00" and "88 .42" become "50.00" and "88.42",
  /// and a bare ".00" becomes "0.00".
  static String _normalizeOcrLine(String line) {
    var text = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceAllMapped(
      RegExp(r'(\d)\s*[.,]\s*[.,]?\s*(\d{2})(?!\d)'),
      (match) => '${match.group(1)}.${match.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<![\d.,])[.,](\d{2})(?!\d)'),
      (match) => '0.${match.group(1)}',
    );
    return text;
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

  static DateTime? _findDate(List<String> lines, DateTime now) {
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

      DateTime? date;
      if (first > 999) {
        date = _validDate(first, second, third, now);
      } else {
        final year = third < 100 ? 2000 + third : third;
        if (first > 12) {
          date = _validDate(year, second, first, now);
        } else if (second > 12) {
          date = _validDate(year, first, second, now);
        } else {
          // Both month/day and day/month are plausible. Canadian receipts use
          // either, so prefer the reading closest to today: receipts are
          // almost always scanned within days of the purchase.
          final monthFirst = _validDate(year, first, second, now);
          final dayFirst = _validDate(year, second, first, now);
          date = _closestToNow(monthFirst, dayFirst, now);
        }
      }
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
        final date = month == null ? null : _validDate(year, month, day, now);
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
        final date = month == null ? null : _validDate(year, month, day, now);
        if (date != null) {
          return date;
        }
      }
    }
    return null;
  }

  static DateTime? _validDate(int year, int month, int day, DateTime now) {
    if (year < 2000 || year > now.year + 1) {
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

  static DateTime? _closestToNow(DateTime? a, DateTime? b, DateTime now) {
    if (a == null) return b;
    if (b == null || a == b) return a;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final aFuture = a.isAfter(tomorrow);
    final bFuture = b.isAfter(tomorrow);
    if (aFuture != bFuture) return aFuture ? b : a;
    return a.difference(now).abs() <= b.difference(now).abs() ? a : b;
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
      if (!labels.any((label) => _startsWord(lower, label)) ||
          excludedLabels.any(lower.contains)) {
        continue;
      }
      final amount =
          _parseAmountAtEnd(line) ??
          _parseAmountAnywhere(line) ??
          _parseOcrSeparatedLabeledAmount(line);
      if (amount != null) {
        return amount;
      }
      // Column-split output puts the amount alone on a neighbouring line.
      final adjacentAmount = _adjacentStandaloneAmount(lines, index);
      if (adjacentAmount != null) return adjacentAmount;
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

  static final RegExp _labelWords = RegExp(
    r'\b(sub\s?total|total|tax|gst|hst|pst|qst|tip|gratuity|amount|'
    r'balance|due|change|cash|tender|discount|saving)',
  );

  static bool _isLabelLine(String line) {
    return _labelWords.hasMatch(_normalizedLabel(line)) &&
        _parseStandaloneAmount(line) == null;
  }

  /// The standalone amount that belongs to the label on [index] when ML Kit
  /// has split a receipt into a label column and an amount column.
  ///
  /// Amounts can land either after their labels ("TOTAL" / "61.50") or
  /// before them ("3.05" / "GST INCLUDED"). When both neighbours are
  /// amounts, follow the alternating run of labels and amounts to its end:
  /// a run that ends with an amount reads label-then-amount, a run that
  /// ends with a label reads amount-then-label.
  static int? _adjacentStandaloneAmount(List<String> lines, int index) {
    final next = index + 1 < lines.length
        ? _parseStandaloneAmount(lines[index + 1])
        : null;
    final previous = index > 0
        ? _parseStandaloneAmount(lines[index - 1])
        : null;
    if (next == null || previous == null) return next ?? previous;

    var end = index;
    var expectAmount = true;
    while (end + 1 < lines.length) {
      final candidate = lines[end + 1];
      final isAmount = _parseStandaloneAmount(candidate) != null;
      if (expectAmount ? !isAmount : !_isLabelLine(candidate)) break;
      end++;
      expectAmount = !expectAmount;
    }
    final endsWithAmount = _parseStandaloneAmount(lines[end]) != null;
    return endsWithAmount ? next : previous;
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
    int? combinedTax;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final lower = _normalizedLabel(line);
      if (!RegExp(r'\b(tax|gst|hst|pst|qst)\b').hasMatch(lower) ||
          lower.contains('taxable')) {
        continue;
      }
      final amount =
          _parseAmountAtEnd(line) ?? _adjacentStandaloneAmount(lines, index);
      if (amount == null || amount < 0) {
        continue;
      }
      // Receipts that print GST and PST on their own lines usually also
      // print a combined "TOTAL TAX" line. Summing all three doubles the tax,
      // so a combined line wins over the individual amounts.
      if (_combinedTaxLabel.hasMatch(lower)) {
        combinedTax = amount;
      } else {
        taxAmounts.add(amount);
      }
    }
    if (combinedTax != null) {
      return combinedTax;
    }
    if (taxAmounts.isEmpty) {
      return null;
    }
    return taxAmounts.fold<int>(0, (sum, amount) => sum + amount);
  }

  static final RegExp _combinedTaxLabel = RegExp(
    r'\b(?:total\s+tax(?:es)?|tax(?:es)?\s+total|taxes)\b',
  );

  static bool _startsWord(String text, String label) {
    return RegExp(r'\b' + RegExp.escape(label)).hasMatch(text);
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
        final value
            when RegExp(r'\bcash\b').hasMatch(value) &&
                !RegExp(r'\bcash\s*back\b').hasMatch(value) =>
          'Cash',
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
    // Capitalise the first letter of every word, including the parts of
    // hyphenated names such as Petro-Canada.
    return trimmed.toLowerCase().replaceAllMapped(
      RegExp(r'(^|[\s\-/])([a-z])'),
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
    );
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
