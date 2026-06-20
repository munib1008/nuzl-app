import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../rbac/persona.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/profile/presentation/public_profile_screen.dart';
import '../../features/profile/presentation/public_org_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/listings/presentation/listings_screen.dart';
import '../../features/listings/presentation/bulk_property_import_screen.dart';
import '../../features/listings/presentation/listing_form_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/public_listing_screen.dart';
import '../../features/documents/property_docs_screen.dart';
import '../../features/opportunities/opportunities_screen.dart';
import '../../features/admin/post_moderation_screen.dart';
import '../../features/admin/founding_owners_screen.dart';
import '../../features/organizations/org_ownership_screen.dart';
import '../../features/organizations/company_dashboard_screen.dart';
import '../../features/organizations/company_edit_screen.dart';
import '../../features/sales/sales_performance_screen.dart';
import '../../features/organizations/partners_screen.dart';
import '../../features/referral/refer_screen.dart';
import '../../features/rewards/rewards_screen.dart';
import '../../features/leads/presentation/lead_market_screen.dart';
import '../../features/reports/lead_analytics_screen.dart';
import '../../features/collaboration/collaboration_screen.dart';
import '../../features/deal_board/deal_board_screen.dart';
import '../../features/leads/presentation/leads_screen.dart';
import '../../features/leads/presentation/lead_crm_screen.dart';
import '../../features/leads/presentation/post_lead_screen.dart';
import '../../features/leads/presentation/bulk_lead_import_screen.dart';
import '../../features/deals/presentation/deals_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/contacts/contacts_screen.dart';
import '../../features/contacts/contact_detail_screen.dart';
import '../../features/marketplace/orders_screen.dart';
import '../../features/team/team_screen.dart';
import '../../features/admin/view_as_screen.dart';
import '../../features/rentals/rentals_screen.dart';
import '../../features/maintenance/maintenance_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/common/stub_screen.dart';
import '../../features/mortgage/presentation/calculator_screen.dart';
import '../../features/mortgage/presentation/finance_planner_screen.dart';
import '../../features/mortgage/presentation/mortgage_list_screen.dart';
import '../../features/mortgage/presentation/mortgage_form_screen.dart';
import '../../features/mortgage/presentation/mortgage_detail_screen.dart';
import '../../features/landing/landing_screen.dart';
import '../../features/marketing/info_page.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/kpi/kpi_screen.dart';
import '../../features/support/support_center_screen.dart';
import '../../features/financials/financials_screen.dart';
import '../../features/documents/documents_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/portfolio/my_properties_screen.dart';
import '../../features/property/property_record_screen.dart';
import '../../features/matching/lead_matches_screen.dart';
import '../../features/activities/activities_screen.dart';
import '../../features/messages/messages_screen.dart';
import '../../features/messages/chat_thread_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/viewings/viewings_screen.dart';
import '../../features/viewings/viewing_leads_screen.dart';
import '../../features/viewings/viewing_crm_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/saved/saved_searches.dart';
import '../../features/marketplace/marketplace_screen.dart';
import '../../features/marketplace/marketplace_item_screen.dart';
import '../../features/marketing/pricing_screen.dart';
import '../../features/network/network_screen.dart';
import '../../features/admin/organizations_screen.dart';
import '../../features/admin/verification_queue_screen.dart';
import '../../features/admin/company_verifications_screen.dart';
import '../../features/admin/role_requests_screen.dart';
import '../../features/tenders/tenders_screen.dart';
import '../../features/tenders/tender_detail_screen.dart';
import '../../features/tenders/quotations_screen.dart';
import '../../features/admin/nuzler_team_screen.dart';
import '../../features/admin/audit_screen.dart';
import '../../features/admin/limits_screen.dart';
import '../../features/billing/plans_screen.dart';
import '../../features/billing/my_plan_screen.dart';
import '../../features/crm/crm_screen.dart';
import '../../features/crm/crm_workspace_screen.dart';
import '../../features/crm/insights_screen.dart';
import '../../features/invoicing/invoicing_screen.dart';
import '../../features/shell/app_shell.dart';
import '../network/api_client.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
    _ref.listen(unauthorizedProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

/// Public routes (no login). The mortgage calculator + marketing pages included.
const _publicPaths = {'/', '/login', '/register', '/forgot', '/reset', '/pricing'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (!auth.initialized) return null;
      final loc = state.matchedLocation;
      final isPublic = _publicPaths.contains(loc) || loc.startsWith('/info/') ||
          loc.startsWith('/u/') || loc.startsWith('/org/') || loc.startsWith('/property/');
      if (!auth.isAuthenticated) return isPublic ? null : '/login';
      // authed users shouldn't sit on landing/login/register. Honor a `next=`
      // intent (e.g. the landing hero search routes through login → results).
      if (loc == '/' || loc == '/login' || loc == '/register') {
        final next = state.uri.queryParameters['next'];
        if (next != null && next.startsWith('/') && !next.startsWith('//')) return next;
        return '/dashboard';
      }
      // Lead posting/pipeline is for agents / agency / freelancer (+ lead-gen) only.
      // Customers are active users but don't run a lead pipeline — bounce them out.
      if (loc == '/leads' || loc.startsWith('/leads/')) {
        if (!ref.read(personaProvider).canManageLeads) return '/dashboard';
      }
      return null;
    },
    routes: [
      // public
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, st) => RegisterScreen(referralCode: st.uri.queryParameters['ref'])),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset', builder: (_, st) => ResetPasswordScreen(token: st.uri.queryParameters['token'] ?? '')),
      GoRoute(path: '/info/:slug', builder: (_, st) => InfoPage(slug: st.pathParameters['slug']!)),
      GoRoute(path: '/u/:id', builder: (_, st) => PublicProfileScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/org/:slug', builder: (_, st) => PublicOrgScreen(slug: st.pathParameters['slug']!)),
      GoRoute(path: '/property/:id', builder: (_, st) => PublicListingScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/pricing', builder: (_, __) => const PricingScreen()),

      // onboarding (authed, full screen)
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // chat thread (authed, full screen — outside the shell so the composer
      // isn't stacked under the mobile bottom-nav). The /messages inbox stays
      // inside the shell below.
      GoRoute(path: '/messages/:id', builder: (_, st) => ChatThreadScreen(id: st.pathParameters['id']!)),

      // authed app — wrapped in a shell that adds the mobile bottom nav.
      // Each screen still carries the NuzlAppBar + role-based NuzlDrawer.
      ShellRoute(
        builder: (_, __, child) => _BottomNavShell(child: child),
        routes: [
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
      GoRoute(path: '/properties', builder: (_, __) => const ListingsScreen()),
      GoRoute(path: '/properties/import', builder: (_, __) => const BulkPropertyImportScreen()),
      GoRoute(path: '/properties/new', builder: (_, __) => const ListingFormScreen()),
      GoRoute(path: '/properties/:id/edit', builder: (_, st) => ListingFormScreen(
            editId: st.pathParameters['id'],
            initial: st.extra is Map<String, dynamic> ? st.extra as Map<String, dynamic> : null)),
      GoRoute(path: '/properties/:id/documents',
            builder: (_, st) => PropertyDocsScreen(propertyId: st.pathParameters['id']!)),
      GoRoute(path: '/listings/:id', builder: (_, st) => ListingDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/leads', builder: (_, __) => const LeadsScreen()),
      GoRoute(path: '/leads/import', builder: (_, __) => const BulkLeadImportScreen()),
      GoRoute(path: '/leads/new', builder: (_, __) => const PostLeadScreen()),
      GoRoute(path: '/leads/:id', builder: (_, st) => LeadCrmScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/deals', builder: (_, __) => const DealsScreen()),
      GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
      GoRoute(path: '/customers/:id', builder: (_, st) => CustomerDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/team', builder: (_, __) => const TeamScreen()),
      GoRoute(path: '/view-as', builder: (_, __) => const ViewAsScreen()),
      GoRoute(path: '/rentals', builder: (_, __) => const RentalsScreen()),
      GoRoute(path: '/maintenance', builder: (_, __) => const MaintenanceScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

      // Phase 2 — completed sections (were /soon placeholders)
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/kpi', builder: (_, __) => const KpiScreen()),
      GoRoute(path: '/support', builder: (_, __) => const SupportCenterScreen()),
      GoRoute(path: '/financials', builder: (_, __) => const FinancialsScreen()),
      GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(path: '/projects', builder: (_, __) => const ProjectsScreen()),
      GoRoute(path: '/projects/:id', builder: (_, s) => ProjectDetailScreen(projectId: s.pathParameters['id']!)),
      GoRoute(path: '/partners', builder: (_, __) => const PartnersScreen()),
      GoRoute(path: '/my-properties', builder: (_, __) => const MyPropertiesScreen()),
      GoRoute(path: '/property/:id', builder: (_, s) => PropertyRecordScreen(propertyId: s.pathParameters['id']!)),
      GoRoute(path: '/lead-matches', builder: (_, __) => const LeadMatchesScreen()),
      // CRM single workspace — /crm is the overview dashboard; every section is
      // a nested /crm/* route so "CRM" stays highlighted across the whole area.
      GoRoute(path: '/crm', builder: (_, __) => const CrmWorkspaceScreen()),
      GoRoute(path: '/crm/pipeline', builder: (_, __) => const OpportunitiesScreen()),
      GoRoute(path: '/crm/contacts', builder: (_, __) => const ContactsScreen()),
      GoRoute(path: '/crm/activities', builder: (_, __) => const ActivitiesScreen()),
      GoRoute(path: '/crm/deals', builder: (_, __) => const DealsScreen()),
      GoRoute(path: '/crm/deal-board', builder: (_, __) => const DealBoardScreen()),
      GoRoute(path: '/crm/collaboration', builder: (_, __) => const CollaborationScreen()),
      GoRoute(path: '/crm/lead-market', builder: (_, __) => const LeadMarketScreen()),
      GoRoute(path: '/crm/invoicing', builder: (_, __) => const InvoicingScreen()),
      // Analytics + Reports merged into one Insights tab; old paths redirect.
      GoRoute(path: '/crm/insights', builder: (_, __) => const InsightsScreen()),
      GoRoute(path: '/crm/analytics', redirect: (_, __) => '/crm/insights'),
      GoRoute(path: '/crm/reports', redirect: (_, __) => '/crm/insights'),
      // Lead-scoring CRM (legacy standalone) kept reachable.
      GoRoute(path: '/crm/scoring', builder: (_, __) => const CrmScreen()),
      // Stand-alone routes (non-CRM personas) — same screens, plain chrome.
      GoRoute(path: '/opportunities', builder: (_, __) => const OpportunitiesScreen()),
      GoRoute(path: '/invoicing', builder: (_, __) => const InvoicingScreen()),
      GoRoute(path: '/contacts', builder: (_, __) => const ContactsScreen()),
      GoRoute(path: '/contacts/:id', builder: (_, st) => ContactDetailScreen(id: st.pathParameters['id']!)),
      // Cockpit merged into the Dashboard — keep the path as a redirect so old
      // links/bookmarks don't dead-end.
      GoRoute(path: '/owner-cockpit', redirect: (_, __) => '/dashboard'),
      GoRoute(path: '/post-moderation', builder: (_, __) => const PostModerationScreen()),
      GoRoute(path: '/founding-owners', builder: (_, __) => const FoundingOwnersScreen()),
      GoRoute(path: '/org-ownership', builder: (_, __) => const OrgOwnershipScreen()),
      GoRoute(path: '/company-dashboard', builder: (_, __) => const CompanyDashboardScreen()),
      GoRoute(path: '/company/edit', builder: (_, __) => const CompanyEditScreen()),
      GoRoute(path: '/sales-performance', builder: (_, __) => const SalesPerformanceScreen()),
      GoRoute(path: '/refer', builder: (_, __) => const ReferScreen()),
      GoRoute(path: '/rewards', builder: (_, __) => const RewardsScreen()),
      GoRoute(path: '/rewards-hub', builder: (_, __) => const RewardsHubScreen()),
      GoRoute(path: '/lead-market', builder: (_, __) => const LeadMarketScreen()),
      GoRoute(path: '/lead-analytics', builder: (_, __) => const LeadAnalyticsScreen()),
      GoRoute(path: '/collaboration', builder: (_, __) => const CollaborationScreen()),
      GoRoute(path: '/deal-board', builder: (_, __) => const DealBoardScreen()),
      GoRoute(path: '/activities', builder: (_, __) => const ActivitiesScreen()),
      GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/viewings', builder: (_, __) => const ViewingsScreen()),
      GoRoute(path: '/viewing-leads', builder: (_, __) => const ViewingLeadsScreen()),
      GoRoute(path: '/viewings/:id/crm', builder: (_, st) => ViewingCrmScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
      GoRoute(path: '/saved-searches', builder: (_, __) => const SavedSearchesScreen()),
      GoRoute(path: '/marketplace', builder: (_, __) => const MarketplaceScreen()),
      GoRoute(path: '/marketplace/:id', builder: (_, st) => MarketplaceItemScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(path: '/tenders', builder: (_, __) => const TendersScreen()),
      GoRoute(path: '/tenders/:id', builder: (_, st) => TenderDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/quotations', builder: (_, __) => const QuotationsScreen()),
      GoRoute(path: '/network', builder: (_, __) => const NetworkScreen()),
      GoRoute(path: '/organizations', builder: (_, __) => const OrganizationsScreen()),
      GoRoute(path: '/verification-queue', builder: (_, __) => const VerificationQueueScreen()),
      GoRoute(path: '/company-verifications', builder: (_, __) => const CompanyVerificationsScreen()),
      GoRoute(path: '/role-requests', builder: (_, __) => const RoleRequestsScreen()),
      GoRoute(path: '/nuzler-team', builder: (_, __) => const NuzlerTeamScreen()),
      GoRoute(path: '/audit', builder: (_, __) => const AuditScreen()),
      GoRoute(path: '/plans', builder: (_, __) => const PlansScreen()),
      GoRoute(path: '/billing', builder: (_, __) => const MyPlanScreen()),
      GoRoute(path: '/limits', builder: (_, __) => const LimitsScreen()),

      GoRoute(path: '/soon/:title', builder: (_, st) => StubScreen(title: st.pathParameters['title']!)),

      // mortgages
      GoRoute(path: '/calculator', builder: (_, __) => const CalculatorScreen()),
      GoRoute(path: '/finance-planner', builder: (_, __) => const FinancePlannerScreen()),
      GoRoute(path: '/mortgages', builder: (_, __) => const MortgageListScreen()),
      GoRoute(path: '/mortgages/new', builder: (_, __) => const MortgageFormScreen()),
      GoRoute(path: '/mortgages/:id', builder: (_, s) => MortgageDetailScreen(id: s.pathParameters['id']!)),
        ],
      ),
    ],
  );
});

/// Wraps authed screens with a mobile bottom nav (narrow widths only); on wide
/// layouts the role-based drawer is enough, so the child renders unchanged.
class _BottomNavShell extends StatelessWidget {
  const _BottomNavShell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Wide: persistent sidebar + content. Medium: drawer only. Narrow: bottom nav.
    if (w >= 1000) {
      return Scaffold(body: Row(children: [const NuzlSidebar(), Expanded(child: child)]));
    }
    // Below 1000 (incl. tablet 600-999, previously a no-nav dead-band): bottom nav.
    // NB: extendBody must stay false. The bottom nav is opaque, and each screen
    // carries its own Scaffold + FloatingActionButton. With extendBody:true the
    // child body extends behind the nav, so those FABs (e.g. Feed "New post",
    // "New listing") float at the very bottom of the screen — hidden behind the
    // nav bar. Keeping the body above the nav lets each screen's FAB sit above it.
    return Scaffold(body: child, bottomNavigationBar: const NuzlBottomNav());
  }
}
