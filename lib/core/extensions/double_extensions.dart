import 'package:intl/intl.dart';

extension PriceFormatting on double {
  String formatPrice() => NumberFormat.currency(
        locale: 'fr_FR',
        symbol: '€',
        decimalDigits: 2,
      ).format(this);
}
