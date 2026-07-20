/// Helpers de formatage d'affichage.
library;

import 'package:intl/intl.dart';

/// Formate un entier en insérant un séparateur de milliers selon la locale.
///
/// Exemple (fr) : `formatThousands(20000)` → `'20 000'`.
/// Exemple (en) : `formatThousands(20000)` → `'20,000'`.
String formatThousands(int value) {
  final formatter = NumberFormat.decimalPattern();
  return formatter.format(value);
}
