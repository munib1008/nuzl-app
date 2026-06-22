/// Finance types for the home-finance tracker (mortgage redesign). `finance_type`
/// is stored as free text on the mortgage; these helpers drive labels + behaviour.
const kFinanceTypes = <(String, String)>[
  ('conventional', 'Conventional Mortgage'),
  ('ijarah', 'Islamic Ijarah'),
  ('murabaha', 'Islamic Murabaha'),
  ('diminishing_musharaka', 'Islamic Diminishing Musharaka'),
  ('cash', 'Cash Purchase'),
  ('developer_plan', 'Developer Payment Plan'),
];

/// Islamic products share the profit/finance/Takaful lexicon. 'islamic' is the
/// legacy value from before the 6-type split — still treated as Islamic.
bool isIslamicFinance(String? t) =>
    t == 'islamic' || t == 'ijarah' || t == 'murabaha' || t == 'diminishing_musharaka';

bool isCashPurchase(String? t) => t == 'cash';
bool isDeveloperPlan(String? t) => t == 'developer_plan';

/// True when there's an amortising/installment finance to track (not an outright cash buy).
bool isFinanced(String? t) => !isCashPurchase(t);

String financeTypeLabel(String? t) {
  for (final e in kFinanceTypes) {
    if (e.$1 == t) return e.$2;
  }
  return t == 'islamic' ? 'Islamic Finance' : 'Conventional Mortgage';
}
