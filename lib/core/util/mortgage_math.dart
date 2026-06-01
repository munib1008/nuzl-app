import 'dart:math';

/// Pure mortgage math — no network, used by the public calculator and tracker.
class MortgageMath {
  /// Standard amortised monthly payment.
  static double monthlyPayment(double principal, double annualRatePct, int termMonths) {
    final r = annualRatePct / 100 / 12;
    if (termMonths <= 0) return 0;
    if (r == 0) return principal / termMonths;
    final f = pow(1 + r, termMonths).toDouble();
    return principal * r * f / (f - 1);
  }

  static double totalPaid(double monthly, int termMonths) => monthly * termMonths;
  static double totalInterest(double principal, double monthly, int termMonths) =>
      max(0, monthly * termMonths - principal);

  /// Outstanding balance after [paymentsMade] payments.
  static double balanceAfter(double principal, double annualRatePct, int termMonths, int paymentsMade) {
    final r = annualRatePct / 100 / 12;
    if (r == 0) return max(0, principal - (principal / termMonths) * paymentsMade);
    final m = monthlyPayment(principal, annualRatePct, termMonths);
    final f = pow(1 + r, paymentsMade).toDouble();
    return max(0, principal * f - m * (f - 1) / r);
  }
}
