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
        NavItem(Icons.dynamic_feed_outlined, 'Feed', '/feed'),
        NavItem(Icons.add_circle_outline, 'Post Lead', '/leads/new'),
        NavItem(Icons.trending_up, 'My Leads', '/leads'),
        NavItem(Icons.auto_awesome_outlined, 'Lead Matches', '/lead-matches'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.people_outline, 'Network', '/network'),
      ];
    case Persona.agent:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.dynamic_feed_outlined, 'Feed', '/feed'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.trending_up, 'CRM', '/opportunities'),
        NavItem(Icons.event_available_outlined, 'Leasing Leads', '/viewing-leads'),
        NavItem(Icons.handshake_outlined, 'Deals', '/deals'),
        NavItem(Icons.diversity_3_outlined, 'Collaboration', '/collaboration'),
        NavItem(Icons.campaign_outlined, 'Deal board', '/deal-board'),
        NavItem(Icons.contacts_outlined, 'Contacts', '/contacts'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.event_note_outlined, 'Activities', '/activities'),
        NavItem(Icons.query_stats_outlined, 'Lead analytics', '/lead-analytics'),
        NavItem(Icons.insights_outlined, 'Reports', '/reports'),
      ];
    case Persona.broker:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.dynamic_feed_outlined, 'Feed', '/feed'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.trending_up, 'CRM', '/opportunities'),
        NavItem(Icons.event_available_outlined, 'Leasing Leads', '/viewing-leads'),
        NavItem(Icons.handshake_outlined, 'Deals', '/deals'),
        NavItem(Icons.diversity_3_outlined, 'Collaboration', '/collaboration'),
        NavItem(Icons.campaign_outlined, 'Deal board', '/deal-board'),
        NavItem(Icons.contacts_outlined, 'Contacts', '/contacts'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.inventory_2_outlined, 'Inventory', '/inventory'),
        NavItem(Icons.groups_outlined, 'Team', '/team'),
        NavItem(Icons.business_outlined, 'Organization', '/org-ownership'),
        NavItem(Icons.query_stats_outlined, 'Lead analytics', '/lead-analytics'),
        NavItem(Icons.insights_outlined, 'Reports', '/reports'),
      ];
    case Persona.developer:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.domain_outlined, 'Projects', '/projects'),
        NavItem(Icons.inventory_2_outlined, 'Inventory', '/inventory'),
        NavItem(Icons.groups_outlined, 'Team', '/team'),
        NavItem(Icons.business_outlined, 'Organization', '/org-ownership'),
        NavItem(Icons.dynamic_feed_outlined, 'Feed', '/feed'),
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
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.storefront_outlined, 'Marketplace', '/marketplace'),
        NavItem(Icons.receipt_long_outlined, 'Orders', '/orders'),
        NavItem(Icons.contacts_outlined, 'Contacts', '/contacts'),
        NavItem(Icons.event_note_outlined, 'Activities', '/activities'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
      ];
    case Persona.provider:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.storefront_outlined, 'Marketplace', '/marketplace'),
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
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.space_dashboard_outlined, 'Cockpit', '/owner-cockpit'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.vpn_key_outlined, 'Rentals', '/rentals'),
        NavItem(Icons.build_outlined, 'Maintenance', '/maintenance'),
        NavItem(Icons.account_balance_wallet_outlined, 'Financials', '/financials'),
        NavItem(Icons.account_balance_outlined, 'Mortgages', '/mortgages'),
        NavItem(Icons.folder_outlined, 'Documents', '/documents'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
      ];
    case Persona.buyer:
      // Customer priority flow: search → save → contact → finance → purchase.
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.bookmark_outline, 'Saved', '/saved'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/messages'),
        NavItem(Icons.account_balance_outlined, 'My Mortgage', '/mortgages'),
        NavItem(Icons.storefront_outlined, 'Marketplace', '/marketplace'),
        NavItem(Icons.receipt_long_outlined, 'Orders', '/orders'),
      ];
    case Persona.admin:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.business_outlined, 'Organizations', '/organizations'),
        NavItem(Icons.verified_user_outlined, 'Verification', '/verification-queue'),
        NavItem(Icons.flag_outlined, 'Moderation', '/post-moderation'),
        NavItem(Icons.badge_outlined, 'Nuzler Team', '/nuzler-team'),
        NavItem(Icons.workspace_premium_outlined, 'Founding Owners', '/founding-owners'),
        NavItem(Icons.receipt_long_outlined, 'Audit Logs', '/audit'),
        NavItem(Icons.workspace_premium_outlined, 'Plans', '/plans'),
        NavItem(Icons.speed_outlined, 'Usage Limits', '/limits'),
        NavItem(Icons.insights_outlined, 'Reports', '/reports'),
      ];
  }
}
