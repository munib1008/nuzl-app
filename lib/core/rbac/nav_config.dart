import 'package:flutter/material.dart';
import 'persona.dart';

class NavItem {
  const NavItem(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

/// Menu items per persona. Real routes where built; '/soon/...' placeholders
/// for sections still on the roadmap so navigation never dead-ends.
List<NavItem> navItemsFor(Persona p) {
  switch (p) {
    case Persona.leadGenerator:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.storefront_outlined, 'Marketplace', '/marketplace'),
        NavItem(Icons.dynamic_feed_outlined, 'Community', '/feed'),
        NavItem(Icons.add_circle_outline, 'Post Lead', '/leads/new'),
        NavItem(Icons.trending_up, 'My Leads', '/leads'),
        NavItem(Icons.sell_outlined, 'Lead Market', '/lead-market'),
        NavItem(Icons.auto_awesome_outlined, 'Lead Matches', '/lead-matches'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.people_outline, 'Network', '/network'),
      ];
    // Consolidated to ~8 modules — Contacts, Activities, Deals, Deal board,
    // Collaboration, Lead Market, Analytics & Reports are all reachable from the
    // CRM hub launchpad on /opportunities, so they're off the flat nav.
    case Persona.agent:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.dynamic_feed_outlined, 'Community', '/feed'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.trending_up, 'CRM', '/crm'),
        NavItem(Icons.event_available_outlined, 'Leasing Leads', '/viewing-leads'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.emoji_events_outlined, 'Performance', '/kpi'),
      ];
    case Persona.broker:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.dynamic_feed_outlined, 'Community', '/feed'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.trending_up, 'CRM', '/crm'),
        NavItem(Icons.event_available_outlined, 'Leasing Leads', '/viewing-leads'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.inventory_2_outlined, 'Inventory', '/inventory'),
        NavItem(Icons.groups_outlined, 'Team', '/team'),
        NavItem(Icons.business_outlined, 'My Company', '/company-dashboard'),
        NavItem(Icons.emoji_events_outlined, 'Performance', '/kpi'),
      ];
    case Persona.developer:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.domain_outlined, 'Projects', '/projects'),
        NavItem(Icons.inventory_2_outlined, 'Inventory', '/inventory'),
        NavItem(Icons.groups_outlined, 'Team', '/team'),
        NavItem(Icons.business_outlined, 'My Company', '/company-dashboard'),
        NavItem(Icons.emoji_events_outlined, 'Performance', '/kpi'),
        NavItem(Icons.dynamic_feed_outlined, 'Community', '/feed'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.insights_outlined, 'Reports', '/reports'),
      ];
    case Persona.bank:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.account_balance_outlined, 'Mortgages', '/mortgages'),
        NavItem(Icons.trending_up, 'Leads', '/leads'),
        NavItem(Icons.contacts_outlined, 'Contacts', '/contacts'),
        NavItem(Icons.groups_outlined, 'Team', '/team'),
        NavItem(Icons.insights_outlined, 'Reports', '/reports'),
      ];
    case Persona.salesperson:
      // Pipeline-focused (spec): Leads → Opportunities → Quotations, not a generic
      // contact list. Quotations are managed via the tendering/requests screen.
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.filter_alt_outlined, 'Leads', '/leads'),
        NavItem(Icons.trending_up_outlined, 'Opportunities', '/opportunities'),
        NavItem(Icons.request_quote_outlined, 'Quotations', '/quotations'),
        NavItem(Icons.event_note_outlined, 'Activities', '/activities'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
      ];
    case Persona.provider:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.business_outlined, 'My Company', '/company-dashboard'),
        NavItem(Icons.storefront_outlined, 'Marketplace', '/marketplace'),
        NavItem(Icons.assignment_outlined, 'Requests', '/tenders'),
        NavItem(Icons.receipt_long_outlined, 'Orders', '/orders'),
        NavItem(Icons.groups_outlined, 'Team', '/team'),
        NavItem(Icons.contacts_outlined, 'Contacts', '/contacts'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.insights_outlined, 'Reports', '/reports'),
      ];
    case Persona.tenant:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.vpn_key_outlined, 'My Tenancy', '/rentals'),
        NavItem(Icons.build_outlined, 'Maintenance', '/maintenance'),
        NavItem(Icons.assignment_outlined, 'Requests', '/tenders'),
        NavItem(Icons.storefront_outlined, 'Marketplace', '/marketplace'),
        NavItem(Icons.folder_outlined, 'Documents', '/documents'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
      ];
    case Persona.investor:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.home_work_outlined, 'My Properties', '/my-properties'),
        NavItem(Icons.account_balance_wallet_outlined, 'Financials', '/financials'),
        NavItem(Icons.account_balance_outlined, 'Mortgages', '/mortgages'),
        NavItem(Icons.build_outlined, 'Maintenance', '/maintenance'),
        NavItem(Icons.folder_outlined, 'Documents', '/documents'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
      ];
    case Persona.owner:
      // Slimmed: the Cockpit merged into the Dashboard, and Financials /
      // Mortgages / Requests are surfaced via dashboard widgets + quick actions
      // (routes still live) — so the top nav stays an operational shortlist.
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.vpn_key_outlined, 'Rentals', '/rentals'),
        NavItem(Icons.build_outlined, 'Maintenance', '/maintenance'),
        NavItem(Icons.storefront_outlined, 'Marketplace', '/marketplace'),
        NavItem(Icons.folder_outlined, 'Documents', '/documents'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
      ];
    case Persona.buyer:
      // Customer flow. 'Saved' is not a separate item — it lives inside
      // Properties (bookmark action in its app bar). First 5 form the mobile
      // bottom bar: Dashboard · Properties · Marketplace · Messages · Finance.
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.storefront_outlined, 'Marketplace', '/marketplace'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.calculate_outlined, 'Finance Planner', '/finance-planner'),
        NavItem(Icons.receipt_long_outlined, 'Orders', '/orders'),
      ];
    case Persona.admin:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.business_outlined, 'Organizations', '/organizations'),
        NavItem(Icons.verified_user_outlined, 'Verification', '/verification-queue'),
        NavItem(Icons.domain_verification_outlined, 'Companies', '/company-verifications'),
        NavItem(Icons.badge_outlined, 'Role requests', '/role-requests'),
        NavItem(Icons.flag_outlined, 'Moderation', '/post-moderation'),
        NavItem(Icons.support_agent_outlined, 'Support Center', '/support'),
        NavItem(Icons.badge_outlined, 'Nuzler Team', '/nuzler-team'),
        NavItem(Icons.workspace_premium_outlined, 'Founding Owners', '/founding-owners'),
        NavItem(Icons.receipt_long_outlined, 'Audit Logs', '/audit'),
        NavItem(Icons.workspace_premium_outlined, 'Plans', '/plans'),
        NavItem(Icons.speed_outlined, 'Usage Limits', '/limits'),
        NavItem(Icons.insights_outlined, 'Reports', '/reports'),
      ];
  }
}
