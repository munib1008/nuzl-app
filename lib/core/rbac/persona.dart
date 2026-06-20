import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/application/auth_controller.dart';

/// The product persona that drives navigation + dashboard per user type.
///
/// Two families:
///  • Property/real-estate side: agent, broker(=Agency), developer, bank, leadGenerator.
///  • Service/product side: salesperson, provider (Maintenance / Interior&Gardens / Seller).
///  • Consumers: owner, investor, buyer(=Customer).
enum Persona { leadGenerator, agent, broker, developer, bank, salesperson, provider, tenant, investor, owner, buyer, admin }

Persona personaFromRole(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'lead_generator':
    case 'leadgen':
      return Persona.leadGenerator;
    case 'agent':
      return Persona.agent;
    case 'broker':
    case 'brokerage_owner':
    case 'agency':
    case 'team_manager':
      return Persona.broker;
    case 'developer':
      return Persona.developer;
    case 'bank':
      return Persona.bank;
    case 'salesperson':
    case 'sales':
      return Persona.salesperson;
    case 'maintenance':
    case 'interior_gardens':
    case 'interior':
    case 'gardens':
    case 'service':
    case 'seller':
    case 'supplier':
    case 'provider':
      return Persona.provider;
    case 'tenant':
      return Persona.tenant;
    case 'investor':
    case 'investor_owner':
      return Persona.investor;
    case 'owner':
    case 'property_owner':
      return Persona.owner;
    case 'customer':
    case 'buyer':
    case 'lead':
      return Persona.buyer;
    case 'admin':
    case 'super_admin':
    case 'nuzler':
      return Persona.admin;
    default:
      return Persona.broker;
  }
}

extension PersonaLabel on Persona {
  String get label => switch (this) {
        Persona.leadGenerator => 'Lead Generator',
        Persona.agent => 'Agent',
        Persona.broker => 'Agency',
        Persona.developer => 'Developer',
        Persona.bank => 'Bank',
        Persona.salesperson => 'Salesperson',
        Persona.provider => 'Service Provider',
        Persona.tenant => 'Tenant',
        Persona.investor => 'Investor',
        Persona.owner => 'Property Owner',
        Persona.buyer => 'Customer',
        Persona.admin => 'Administrator',
      };
}

/// Capability flags derived from the persona. These are the single source of
/// truth for what each role can do — mirror the same checks in the API guards.
extension PersonaCapabilities on Persona {
  /// AGENCY | AGENT | OWNER | DEVELOPER may create property listings.
  bool get canListProperty => switch (this) {
        Persona.broker || Persona.agent || Persona.owner || Persona.developer || Persona.admin => true,
        _ => false,
      };

  /// AGENCY | AGENT | LEAD-GEN | BANK run a leads pipeline.
  bool get canManageLeads => switch (this) {
        Persona.broker || Persona.agent || Persona.leadGenerator || Persona.bank || Persona.admin => true,
        _ => false,
      };

  /// AGENCY | DEVELOPER | BANK | PROVIDER manage a team (agents / salespeople).
  bool get canManageTeam => switch (this) {
        Persona.broker || Persona.developer || Persona.bank || Persona.provider || Persona.admin => true,
        _ => false,
      };

  /// SALESPERSON | PROVIDER (+ property roles) list services/products in the marketplace.
  bool get canListMarketplace => switch (this) {
        Persona.salesperson || Persona.provider || Persona.broker || Persona.agent || Persona.admin => true,
        _ => false,
      };

  /// OWNER | INVESTOR hold a property portfolio.
  bool get canManagePortfolio => switch (this) {
        Persona.owner || Persona.investor || Persona.admin => true,
        _ => false,
      };

  /// Real-estate professional side (vs service/product or consumer).
  bool get isPropertyPro => switch (this) {
        Persona.broker || Persona.agent || Persona.developer || Persona.bank || Persona.leadGenerator => true,
        _ => false,
      };

  /// Service / product provider side (Maintenance / Interior&Gardens / Seller).
  bool get isServiceProvider => this == Persona.salesperson || this == Persona.provider;

  /// BUYER (Customer) browses only — no listing, pipeline, or portfolio.
  bool get browseOnly => this == Persona.buyer;
}

Persona? _personaByName(String name) {
  for (final p in Persona.values) {
    if (p.name == name) return p;
  }
  return null;
}

/// The user's chosen working persona, persisted per-user. The API `users.role`
/// enum can't yet store every marketplace role, so we keep the choice locally so
/// it survives reloads. Set at onboarding / profile.
class PersonaOverrideNotifier extends StateNotifier<Persona?> {
  PersonaOverrideNotifier(this._userId) : super(null) {
    _load();
  }
  final String? _userId;
  static const _storage = FlutterSecureStorage();
  String? get _key => (_userId == null || _userId.isEmpty) ? null : 'nuzl_persona_$_userId';

  Future<void> _load() async {
    final k = _key;
    if (k == null) return;
    final v = await _storage.read(key: k);
    if (v != null) {
      final p = _personaByName(v);
      if (p != null) state = p;
    }
  }

  Future<void> set(Persona? p) async {
    state = p;
    final k = _key;
    if (k == null) return;
    if (p == null) {
      await _storage.delete(key: k);
    } else {
      await _storage.write(key: k, value: p.name);
    }
  }
}

final personaOverrideProvider =
    StateNotifierProvider<PersonaOverrideNotifier, Persona?>((ref) {
  final userId = ref.watch(authControllerProvider).user?.id;
  return PersonaOverrideNotifier(userId);
});

/// Ephemeral admin "view as role" preview — NOT persisted, reverts on reload.
final personaPreviewProvider = StateProvider<Persona?>((ref) => null);

final personaProvider = Provider<Persona>((ref) {
  // 1) admin preview (temporary)  2) server active_role (UAT #3, durable across
  // devices)  3) legacy device-local override  4) API enum role.
  final preview = ref.watch(personaPreviewProvider);
  if (preview != null) return preview;
  final user = ref.watch(authControllerProvider).user;
  final active = user?.activeRole;
  if (active != null && active.isNotEmpty) return personaFromRole(active);
  final override = ref.watch(personaOverrideProvider);
  if (override != null) return override;
  return personaFromRole(user?.role);
});
