import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/application/auth_controller.dart';

/// The product persona that drives navigation + dashboard per user type.
enum Persona { leadGenerator, agent, broker, developer, investor, owner, buyer, admin }

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
    case 'investor':
    case 'investor_owner':
    case 'customer':
      return Persona.investor;
    case 'owner':
    case 'property_owner':
      return Persona.owner;
    case 'buyer':
      return Persona.buyer;
    case 'admin':
    case 'super_admin':
      return Persona.admin;
    default:
      return Persona.broker;
  }
}

extension PersonaLabel on Persona {
  String get label => switch (this) {
        Persona.leadGenerator => 'Lead Generator',
        Persona.agent => 'Agent',
        Persona.broker => 'Broker / Agency',
        Persona.developer => 'Developer',
        Persona.investor => 'Investor',
        Persona.owner => 'Property Owner',
        Persona.buyer => 'Customer',
        Persona.admin => 'Administrator',
      };
}

/// Capability flags derived from the persona. These are the single source of
/// truth for what each role can do — mirror the same checks in the API guards.
extension PersonaCapabilities on Persona {
  /// AGENCY | AGENT | OWNER (+ operator roles) may create property listings.
  bool get canListProperty => switch (this) {
        Persona.broker || Persona.agent || Persona.owner || Persona.developer || Persona.admin => true,
        _ => false,
      };

  /// AGENCY | AGENT (+ lead generators) manage the leads pipeline.
  bool get canManageLeads => switch (this) {
        Persona.broker || Persona.agent || Persona.leadGenerator || Persona.admin => true,
        _ => false,
      };

  /// Only AGENCY manages a team of agents.
  bool get canManageTeam => this == Persona.broker || this == Persona.admin;

  /// OWNER | INVESTOR hold a property portfolio.
  bool get canManagePortfolio => switch (this) {
        Persona.owner || Persona.investor || Persona.admin => true,
        _ => false,
      };

  /// BUYER | INVESTOR browse only — they cannot list or run a pipeline.
  bool get browseOnly => this == Persona.buyer || this == Persona.investor;
}

Persona? _personaByName(String name) {
  for (final p in Persona.values) {
    if (p.name == name) return p;
  }
  return null;
}

/// The user's chosen working persona, persisted per-user. The API `users.role`
/// enum can't yet store the marketplace roles (agency/agent/owner/investor/
/// buyer), so we keep the choice locally so it survives reloads. Set at
/// onboarding / profile.
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
  // 1) admin preview (temporary)  2) persisted working persona  3) API role.
  final preview = ref.watch(personaPreviewProvider);
  if (preview != null) return preview;
  final override = ref.watch(personaOverrideProvider);
  if (override != null) return override;
  final role = ref.watch(authControllerProvider).user?.role;
  return personaFromRole(role);
});
