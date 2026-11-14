class CurrencyFormatter {
  static double roundTwo(double value) => (value * 100).round() / 100;

  static double roundFour(double value) => (value * 10000).round() / 10000;

  static double usdToBs(double usd, double bcvRate) {
    return roundTwo(usd * bcvRate);
  }

  static double bsToUsd(double bs, double bcvRate) {
    if (bcvRate <= 0) return 0.0;
    return roundTwo(bs / bcvRate);
  }

  static String formatUsd(double amount) {
    return '\$ ${amount.toStringAsFixed(2)}';
  }

  static String formatBs(double amount) {
    final isNegative = amount < 0;
    final fixed = amount.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(intPart[i]);
    }

    return '${isNegative ? '-' : ''}Bs. ${buffer.toString()},$decPart';
  }
}