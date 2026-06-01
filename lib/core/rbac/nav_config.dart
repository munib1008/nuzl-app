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
        NavItem(Icons.storefront_outlined, 'Marketplace', '/feed'),
        NavItem(Icons.add_circle_outline, 'Post Lead', '/soon/Post Lead'),
        NavItem(Icons.trending_up, 'My Leads', '/leads'),
        NavItem(Icons.auto_awesome_outlined, 'Lead Matches', '/soon/Lead Matches'),
        NavItem(Icons.chat_bubble_outline, 'Messages', '/soon/Messages'),
        NavItem(Icons.people_outline, 'Network', '/soon/Network'),
      ];
    case Persona.agent:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.dynamic_feed_outlined, 'Feed', '/feed'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.trending_up, 'Leads', '/leads'),
        NavItem(Icons.handshake_outlined, 'Deals', '/deals'),
        NavItem(Icons.contacts_outlined, 'Customers', '/soon/Customers'),
        NavItem(Icons.event_note_outlined, 'Activities', '/soon/Activities'),
        NavItem(Icons.insights_outlined, 'Reports', '/soon/Reports'),
      ];
    case Persona.broker:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.dynamic_feed_outlined, 'Feed', '/feed'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.trending_up, 'Leads', '/leads'),
        NavItem(Icons.handshake_outlined, 'Deals', '/deals'),
        NavItem(Icons.contacts_outlined, 'Customers', '/soon/Customers'),
        NavItem(Icons.inventory_2_outlined, 'Inventory', '/soon/Inventory'),
        NavItem(Icons.groups_outlined, 'Team', '/soon/Team'),
        NavItem(Icons.insights_outlined, 'Reports', '/soon/Reports'),
      ];
    case Persona.developer:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.domain_outlined, 'Projects', '/soon/Projects'),
        NavItem(Icons.inventory_2_outlined, 'Inventory', '/soon/Inventory'),
        NavItem(Icons.dynamic_feed_outlined, 'Feed', '/feed'),
        NavItem(Icons.insights_outlined, 'Reports', '/soon/Reports'),
      ];
    case Persona.investor:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.home_work_outlined, 'My Properties', '/soon/My Properties'),
        NavItem(Icons.account_balance_wallet_outlined, 'Financials', '/soon/Financials'),
        NavItem(Icons.account_balance_outlined, 'Mortgages', '/mortgages'),
        NavItem(Icons.folder_outlined, 'Documents', '/soon/Documents'),
      ];
    case Persona.owner:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.apartment_outlined, 'Properties', '/properties'),
        NavItem(Icons.vpn_key_outlined, 'Rentals', '/soon/Rentals'),
        NavItem(Icons.account_balance_wallet_outlined, 'Financials', '/soon/Financials'),
        NavItem(Icons.account_balance_outlined, 'Mortgages', '/mortgages'),
        NavItem(Icons.folder_outlined, 'Documents', '/soon/Documents'),
      ];
    case Persona.admin:
      return const [
        NavItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard'),
        NavItem(Icons.business_outlined, 'Organizations', '/soon/Organizations'),
        NavItem(Icons.receipt_long_outlined, 'Audit Logs', '/soon/Audit Logs'),
        NavItem(Icons.workspace_premium_outlined, 'Plans', '/soon/Plans'),
        NavItem(Icons.insights_outlined, 'Reports', '/soon/Reports'),
      ];
  }
}
