import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Onboarding can override the persona for the session.
final personaOverrideProvider = StateProvider<Persona?>((ref) => null);

final personaProvider = Provider<Persona>((ref) {
  final override = ref.watch(personaOverrideProvider);
  if (override != null) return override;
  final role = ref.watch(authControllerProvider).user?.role;
  return personaFromRole(role);
});
