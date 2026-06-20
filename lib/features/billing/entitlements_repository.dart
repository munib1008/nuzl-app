import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

/// The caller's resolved plan + unlocked features + the full plan catalogue.
class Entitlements {
  Entitlements({
    required this.plan,
    required this.planName,
    required this.priceAed,
    required this.features,
    required this.enforced,
    required this.allPlans,
  });

  final String plan;
  final String planName;
  final num priceAed;
  final List<String> features;
  final bool enforced;
  final List<PlanOption> allPlans;

  bool has(String feature) => features.contains(feature);

  factory Entitlements.fromJson(Map<String, dynamic> j) => Entitlements(
        plan: '${j['plan'] ?? 'free'}',
        planName: '${j['plan_name'] ?? 'Free'}',
        priceAed: (j['price_aed'] is num) ? j['price_aed'] as num : 0,
        features: ((j['features'] as List?) ?? const []).map((e) => '$e').toList(),
        enforced: j['enforced'] == true,
        allPlans: ((j['all_plans'] as List?) ?? const [])
            .map((e) => PlanOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static Entitlements get free => Entitlements(
        plan: 'free', planName: 'Free', priceAed: 0, features: const [], enforced: false, allPlans: const []);
}

class PlanOption {
  PlanOption({required this.key, required this.name, required this.priceAed, required this.rank, required this.features});
  final String key;
  final String name;
  final num priceAed;
  final int rank;
  final List<String> features;

  factory PlanOption.fromJson(Map<String, dynamic> j) => PlanOption(
        key: '${j['key']}',
        name: '${j['name']}',
        priceAed: (j['price_aed'] is num) ? j['price_aed'] as num : 0,
        rank: (j['rank'] is num) ? (j['rank'] as num).toInt() : 0,
        features: ((j['features'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

/// Human labels for the canonical feature keys (shown on the plan cards).
const Map<String, String> kFeatureLabels = {
  'crm_contacts': 'CRM contacts',
  'messages': 'Messaging',
  'saved_search': 'Saved searches & alerts',
  'properties_browse': 'Browse & save properties',
  'crm_pipeline': 'Full CRM pipeline (deals, activities)',
  'deal_board': 'Deal board (co-broking)',
  'lead_market': 'Lead marketplace',
  'invoicing': 'Quotations & invoices',
  'analytics': 'Lead & sales analytics',
  'bulk_import': 'Bulk lead / listing import',
  'team_management': 'Team management',
  'org_reports': 'Company reports & leaderboard',
  'kpi_leaderboard': 'KPI leaderboard',
  'api_access': 'API access',
  'white_label': 'White-label branding',
  'priority_support': 'Priority support',
};

String featureLabel(String key) => kFeatureLabels[key] ?? key.replaceAll('_', ' ');

final entitlementsProvider = FutureProvider.autoDispose<Entitlements>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/entitlements/me');
    return d is Map ? Entitlements.fromJson(Map<String, dynamic>.from(d)) : Entitlements.free;
  } catch (_) {
    return Entitlements.free;
  }
});
