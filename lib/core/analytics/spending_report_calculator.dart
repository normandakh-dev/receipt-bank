enum SpendingReportGrouping { weekly, monthly, yearly }

class SpendingRecord {
  const SpendingRecord({required this.date, required this.cents});

  final DateTime date;
  final int cents;
}

class SpendingPeriodTotal {
  const SpendingPeriodTotal({
    required this.start,
    required this.endExclusive,
    required this.totalCents,
    required this.receiptCount,
  });

  final DateTime start;
  final DateTime endExclusive;
  final int totalCents;
  final int receiptCount;
}

class SpendingReportCalculator {
  const SpendingReportCalculator._();

  static int currentWeekTotal(List<SpendingRecord> records, DateTime now) {
    return _sumBetween(
      records,
      startOfWeek(now),
      startOfWeek(now).add(const Duration(days: 7)),
    );
  }

  static int currentMonthTotal(List<SpendingRecord> records, DateTime now) {
    final start = DateTime(now.year, now.month);
    return _sumBetween(records, start, DateTime(now.year, now.month + 1));
  }

  static int currentYearTotal(List<SpendingRecord> records, DateTime now) {
    return _sumBetween(records, DateTime(now.year), DateTime(now.year + 1));
  }

  static List<SpendingPeriodTotal> group(
    List<SpendingRecord> records,
    SpendingReportGrouping grouping,
  ) {
    final totals = <DateTime, ({int cents, int count})>{};
    for (final record in records) {
      final start = switch (grouping) {
        SpendingReportGrouping.weekly => startOfWeek(record.date),
        SpendingReportGrouping.monthly => DateTime(
          record.date.year,
          record.date.month,
        ),
        SpendingReportGrouping.yearly => DateTime(record.date.year),
      };
      final previous = totals[start] ?? (cents: 0, count: 0);
      totals[start] = (
        cents: previous.cents + record.cents,
        count: previous.count + 1,
      );
    }

    final result = totals.entries.map((entry) {
      final end = switch (grouping) {
        SpendingReportGrouping.weekly => entry.key.add(const Duration(days: 7)),
        SpendingReportGrouping.monthly => DateTime(
          entry.key.year,
          entry.key.month + 1,
        ),
        SpendingReportGrouping.yearly => DateTime(entry.key.year + 1),
      };
      return SpendingPeriodTotal(
        start: entry.key,
        endExclusive: end,
        totalCents: entry.value.cents,
        receiptCount: entry.value.count,
      );
    }).toList();
    result.sort((a, b) => b.start.compareTo(a.start));
    return result;
  }

  static DateTime startOfWeek(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  static int _sumBetween(
    List<SpendingRecord> records,
    DateTime start,
    DateTime endExclusive,
  ) {
    return records
        .where(
          (record) =>
              !record.date.isBefore(start) &&
              record.date.isBefore(endExclusive),
        )
        .fold(0, (sum, record) => sum + record.cents);
  }
}
