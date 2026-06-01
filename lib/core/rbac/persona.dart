import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/application/auth_controller.dart';

/// The product persona that drives navigation + dashboard per user type.
enum Persona { leadGenerator, agent, broker, developer, investor, owner, admin }

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
        Persona.admin => 'Administrator',
      };
}

/// Onboarding can override the persona for the session.
final personaOverrideProvider = StateProvider<Persona?>((ref) => null);

final personaProvider = Provider<Persona>((ref) {
  final override = ref.watch(personaOverrideProvider);
  if (override != null) return override;
  final role = ref.watch(authControllerProvider).user?.role;
  return personaFromRole(role);
});
