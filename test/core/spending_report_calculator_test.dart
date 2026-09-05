import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_vault_ai/core/analytics/spending_report_calculator.dart';

void main() {
  final records = [
    SpendingRecord(date: DateTime(2026, 7, 26), cents: 1000),
    SpendingRecord(date: DateTime(2026, 7, 27), cents: 2000),
    SpendingRecord(date: DateTime(2026, 7, 29), cents: 3000),
    SpendingRecord(date: DateTime(2026, 6, 30), cents: 4000),
    SpendingRecord(date: DateTime(2025, 12, 31), cents: 5000),
  ];

  test('calculates current weekly, monthly, and yearly sums', () {
    final now = DateTime(2026, 7, 29);

    expect(SpendingReportCalculator.currentWeekTotal(records, now), 5000);
    expect(SpendingReportCalculator.currentMonthTotal(records, now), 6000);
    expect(SpendingReportCalculator.currentYearTotal(records, now), 10000);
  });

  test('groups sums and counts by month', () {
    final totals = SpendingReportCalculator.group(
      records,
      SpendingReportGrouping.monthly,
    );

    expect(totals, hasLength(3));
    expect(totals[0].start, DateTime(2026, 7));
    expect(totals[0].totalCents, 6000);
    expect(totals[0].receiptCount, 3);
    expect(totals[1].start, DateTime(2026, 6));
    expect(totals[1].totalCents, 4000);
  });

  test('keeps a week together when it spans a daylight-saving change', () {
    // Vancouver springs forward on Sunday 8 March 2026.
    final weekRecords = [
      SpendingRecord(date: DateTime(2026, 3, 2), cents: 100),
      SpendingRecord(date: DateTime(2026, 3, 7), cents: 200),
      SpendingRecord(date: DateTime(2026, 3, 8), cents: 300),
    ];
    final totals = SpendingReportCalculator.group(
      weekRecords,
      SpendingReportGrouping.weekly,
    );

    expect(totals, hasLength(1));
    expect(totals.single.start, DateTime(2026, 3, 2));
    expect(totals.single.endExclusive, DateTime(2026, 3, 9));
    expect(totals.single.totalCents, 600);
    expect(
      SpendingReportCalculator.startOfWeek(DateTime(2026, 3, 8)),
      DateTime(2026, 3, 2),
    );
  });

  test('uses Monday as the beginning of a weekly report', () {
    expect(
      SpendingReportCalculator.startOfWeek(DateTime(2026, 7, 29)),
      DateTime(2026, 7, 27),
    );
    final totals = SpendingReportCalculator.group(
      records,
      SpendingReportGrouping.weekly,
    );
    expect(totals.first.start, DateTime(2026, 7, 27));
    expect(totals.first.totalCents, 5000);
  });
}
