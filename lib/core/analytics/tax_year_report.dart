class TaxExpenseRecord {
  const TaxExpenseRecord({
    required this.date,
    required this.totalCents,
    required this.taxCents,
  });

  final DateTime date;
  final int totalCents;
  final int taxCents;
}

class MonthlyTaxExpense {
  const MonthlyTaxExpense({
    required this.year,
    required this.month,
    required this.totalCents,
    required this.taxCents,
    required this.receiptCount,
  });

  final int year;
  final int month;
  final int totalCents;
  final int taxCents;
  final int receiptCount;
}

class TaxYearReport {
  const TaxYearReport({
    required this.year,
    required this.months,
    required this.totalCents,
    required this.taxCents,
    required this.receiptCount,
  });

  final int year;
  final List<MonthlyTaxExpense> months;
  final int totalCents;
  final int taxCents;
  final int receiptCount;
}

abstract final class TaxYearReportCalculator {
  static TaxYearReport calculate(Iterable<TaxExpenseRecord> records, int year) {
    final totals = List<int>.filled(12, 0);
    final taxes = List<int>.filled(12, 0);
    final counts = List<int>.filled(12, 0);

    for (final record in records) {
      if (record.date.year != year) {
        continue;
      }
      final index = record.date.month - 1;
      totals[index] += record.totalCents;
      taxes[index] += record.taxCents;
      counts[index] += 1;
    }

    final months = List<MonthlyTaxExpense>.generate(
      12,
      (index) => MonthlyTaxExpense(
        year: year,
        month: index + 1,
        totalCents: totals[index],
        taxCents: taxes[index],
        receiptCount: counts[index],
      ),
      growable: false,
    );

    return TaxYearReport(
      year: year,
      months: months,
      totalCents: totals.fold(0, (sum, value) => sum + value),
      taxCents: taxes.fold(0, (sum, value) => sum + value),
      receiptCount: counts.fold(0, (sum, value) => sum + value),
    );
  }
}
