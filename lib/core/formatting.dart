/// Helpers de formatage d'affichage.
library;

/// Formate un entier en insérant une espace comme séparateur de milliers.
///
/// Exemple : `formatThousands(20000)` → `'20 000'`.
String formatThousands(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();

  final buffer = StringBuffer();
  final remainder = digits.length % 3;

  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (i - remainder) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }

  return negative ? '-${buffer.toString()}' : buffer.toString();
}
