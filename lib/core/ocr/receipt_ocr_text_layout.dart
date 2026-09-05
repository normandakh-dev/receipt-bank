class ReceiptOcrTextLayout {
  const ReceiptOcrTextLayout._();

  static String arrange(
    Iterable<ReceiptOcrTextFragment> fragments, {
    String fallback = '',
  }) {
    final ordered =
        fragments
            .where((fragment) => fragment.text.trim().isNotEmpty)
            .toList(growable: false)
          ..sort((a, b) {
            final vertical = a.centerY.compareTo(b.centerY);
            return vertical != 0 ? vertical : a.left.compareTo(b.left);
          });
    if (ordered.isEmpty) return fallback;

    final rows = <_ReceiptOcrTextRow>[];
    for (final fragment in ordered) {
      final currentRow = rows.isEmpty ? null : rows.last;
      if (currentRow != null && currentRow.accepts(fragment)) {
        currentRow.add(fragment);
      } else {
        rows.add(_ReceiptOcrTextRow(fragment));
      }
    }

    return rows.map((row) => row.text).join('\n');
  }
}

class ReceiptOcrTextFragment {
  const ReceiptOcrTextFragment({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  double get centerY => top + (height / 2);
}

class _ReceiptOcrTextRow {
  _ReceiptOcrTextRow(ReceiptOcrTextFragment first)
    : _fragments = [first],
      _centerY = first.centerY,
      _averageHeight = first.height;

  final List<ReceiptOcrTextFragment> _fragments;
  double _centerY;
  double _averageHeight;

  bool accepts(ReceiptOcrTextFragment fragment) {
    final smallerHeight = _averageHeight < fragment.height
        ? _averageHeight
        : fragment.height;
    final tolerance = (smallerHeight * 0.45).clamp(3.0, 18.0);
    return (fragment.centerY - _centerY).abs() <= tolerance;
  }

  void add(ReceiptOcrTextFragment fragment) {
    final previousCount = _fragments.length;
    _fragments.add(fragment);
    _centerY =
        ((_centerY * previousCount) + fragment.centerY) / _fragments.length;
    _averageHeight =
        ((_averageHeight * previousCount) + fragment.height) /
        _fragments.length;
  }

  String get text {
    _fragments.sort((a, b) => a.left.compareTo(b.left));
    return _fragments.map((fragment) => fragment.text.trim()).join(' ');
  }
}
