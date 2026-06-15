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
import '../../features/listings/presentation/listing_form_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import '../../features/leads/presentation/leads_screen.dart';
import '../../features/leads/presentation/post_lead_screen.dart';
import '../../features/deals/presentation/deals_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/team/team_screen.dart';
import '../../features/admin/view_as_screen.dart';
import '../../features/rentals/rentals_screen.dart';
import '../../features/maintenance/maintenance_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/common/stub_screen.dart';
import '../../features/mortgage/presentation/calculator_screen.dart';
import '../../features/mortgage/presentation/mortgage_list_screen.dart';
import '../../features/mortgage/presentation/mortgage_form_screen.dart';
import '../../features/mortgage/presentation/mortgage_detail_screen.dart';
import '../../features/landing/landing_screen.dart';
import '../../features/marketing/info_page.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/financials/financials_screen.dart';
import '../../features/documents/documents_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/portfolio/my_properties_screen.dart';
import '../../features/matching/lead_matches_screen.dart';
import '../../features/activities/activities_screen.dart';
import '../../features/messages/messages_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/viewings/viewings_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/saved/saved_searches.dart';
import '../../features/marketplace/marketplace_screen.dart';
import '../../features/network/network_screen.dart';
import '../../features/admin/organizations_screen.dart';
import '../../features/admin/audit_screen.dart';
import '../../features/admin/limits_screen.dart';
import '../../features/billing/plans_screen.dart';
import '../../features/crm/crm_screen.dart';
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
const _publicPaths = {'/', '/login', '/register', '/forgot', '/reset'};

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
          loc.startsWith('/u/') || loc.startsWith('/org/');
      if (!auth.isAuthenticated) return isPublic ? null : '/login';
      // authed users shouldn't sit on landing/login/register
      if (loc == '/' || loc == '/login' || loc == '/register') return '/dashboard';
      // Lead posting/pipeline is for agents / agency / freelancer (+ lead-gen) only.
      // Customers are active users but don't run a lead pipeline — bounce them out.
      if (loc == '/leads' || loc == '/leads/new') {
        if (!ref.read(personaProvider).canManageLeads) return '/dashboard';
      }
      return null;
    },
    routes: [
      // public
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset', builder: (_, st) => ResetPasswordScreen(token: st.uri.queryParameters['token'] ?? '')),
      GoRoute(path: '/info/:slug', builder: (_, st) => InfoPage(slug: st.pathParameters['slug']!)),
      GoRoute(path: '/u/:id', builder: (_, st) => PublicProfileScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/org/:slug', builder: (_, st) => PublicOrgScreen(slug: st.pathParameters['slug']!)),

      // onboarding (authed, full screen)
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // authed app — wrapped in a shell that adds the mobile bottom nav.
      // Each screen still carries the NuzlAppBar + role-based NuzlDrawer.
      ShellRoute(
        builder: (_, __, child) => _BottomNavShell(child: child),
        routes: [
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
      GoRoute(path: '/properties', builder: (_, __) => const ListingsScreen()),
      GoRoute(path: '/properties/new', builder: (_, __) => const ListingFormScreen()),
      GoRoute(path: '/properties/:id/edit', builder: (_, st) => ListingFormScreen(
            editId: st.pathParameters['id'],
            initial: st.extra is Map<String, dynamic> ? st.extra as Map<String, dynamic> : null)),
      GoRoute(path: '/listings/:id', builder: (_, st) => ListingDetailScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/leads', builder: (_, __) => const LeadsScreen()),
      GoRoute(path: '/leads/new', builder: (_, __) => const PostLeadScreen()),
      GoRoute(path: '/deals', builder: (_, __) => const DealsScreen()),
      GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
      GoRoute(path: '/team', builder: (_, __) => const TeamScreen()),
      GoRoute(path: '/view-as', builder: (_, __) => const ViewAsScreen()),
      GoRoute(path: '/rentals', builder: (_, __) => const RentalsScreen()),
      GoRoute(path: '/maintenance', builder: (_, __) => const MaintenanceScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

      // Phase 2 — completed sections (were /soon placeholders)
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/financials', builder: (_, __) => const FinancialsScreen()),
      GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(path: '/projects', builder: (_, __) => const ProjectsScreen()),
      GoRoute(path: '/my-properties', builder: (_, __) => const MyPropertiesScreen()),
      GoRoute(path: '/lead-matches', builder: (_, __) => const LeadMatchesScreen()),
      GoRoute(path: '/crm', builder: (_, __) => const CrmScreen()),
      GoRoute(path: '/activities', builder: (_, __) => const ActivitiesScreen()),
      GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/viewings', builder: (_, __) => const ViewingsScreen()),
      GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
      GoRoute(path: '/saved-searches', builder: (_, __) => const SavedSearchesScreen()),
      GoRoute(path: '/marketplace', builder: (_, __) => const MarketplaceScreen()),
      GoRoute(path: '/network', builder: (_, __) => const NetworkScreen()),
      GoRoute(path: '/organizations', builder: (_, __) => const OrganizationsScreen()),
      GoRoute(path: '/audit', builder: (_, __) => const AuditScreen()),
      GoRoute(path: '/plans', builder: (_, __) => const PlansScreen()),
      GoRoute(path: '/limits', builder: (_, __) => const LimitsScreen()),

      GoRoute(path: '/soon/:title', builder: (_, st) => StubScreen(title: st.pathParameters['title']!)),

      // mortgages
      GoRoute(path: '/calculator', builder: (_, __) => const CalculatorScreen()),
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
