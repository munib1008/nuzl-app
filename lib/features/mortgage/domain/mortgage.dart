class Mortgage {
  Mortgage({required this.id, this.label, this.lender, required this.principal,
    required this.interestRate, required this.termMonths, this.monthlyPayment,
    this.outstanding, this.paymentsMade = 0});
  final String id;
  final String? label;
  final String? lender;
  final num principal;
  final num interestRate;
  final int termMonths;
  final num? monthlyPayment;
  final num? outstanding;
  final int paymentsMade;

  factory Mortgage.fromJson(Map<String, dynamic> j) => Mortgage(
        id: j['id'].toString(),
        label: j['label'],
        lender: j['lender'],
        principal: _n(j['principal']) ?? 0,
        interestRate: _n(j['interest_rate']) ?? 0,
        termMonths: j['term_months'] is int ? j['term_months'] : int.tryParse('${j['term_months']}') ?? 0,
        monthlyPayment: _n(j['monthly_payment']),
        outstanding: _n(j['outstanding']),
        paymentsMade: j['payments_made'] is int ? j['payments_made'] : int.tryParse('${j['payments_made']}') ?? 0,
      );
  static num? _n(v) => v is num ? v : num.tryParse('$v');
}

class MortgagePayment {
  MortgagePayment({required this.amount, this.principalPart, this.interestPart, this.paidOn});
  final num amount;
  final num? principalPart;
  final num? interestPart;
  final DateTime? paidOn;
  factory MortgagePayment.fromJson(Map<String, dynamic> j) => MortgagePayment(
        amount: Mortgage._n(j['amount']) ?? 0,
        principalPart: Mortgage._n(j['principal_part']),
        interestPart: Mortgage._n(j['interest_part']),
        paidOn: DateTime.tryParse('${j['paid_on']}'),
      );
}
