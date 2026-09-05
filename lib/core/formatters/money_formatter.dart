import 'package:intl/intl.dart';
import 'package:receipt_vault_ai/core/constants/app_constants.dart';

abstract final class MoneyFormatter {
  static String formatCents(
    int cents, {
    String currencyCode = AppConstants.defaultCurrencyCode,
    String locale = AppConstants.defaultLocale,
  }) {
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: currencyCode,
    ).format(cents / 100);
  }
}
