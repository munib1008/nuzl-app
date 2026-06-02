import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/listings/presentation/listings_screen.dart';
import '../../features/listings/presentation/listing_form_screen.dart';
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
import '../network/api_client.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
    _ref.listen(unauthorizedProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

/// Public routes (no login). The mortgage calculator + marketing pages included.
const _publicPaths = {'/', '/login', '/register', '/calculator'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (!auth.initialized) return null;
      final loc = state.matchedLocation;
      final isPublic = _publicPaths.contains(loc) || loc.startsWith('/info/');
      if (!auth.isAuthenticated) return isPublic ? null : '/login';
      // authed users shouldn't sit on landing/login/register
      if (loc == '/' || loc == '/login' || loc == '/register') return '/dashboard';
      return null;
    },
    routes: [
      // public
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/calculator', builder: (_, __) => const CalculatorScreen()),
      GoRoute(path: '/info/:slug', builder: (_, st) => InfoPage(slug: st.pathParameters['slug']!)),

      // onboarding (authed, full screen)
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // authed app — each screen carries the NuzlAppBar + role-based NuzlDrawer
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
      GoRoute(path: '/properties', builder: (_, __) => const ListingsScreen()),
      GoRoute(path: '/properties/new', builder: (_, __) => const ListingFormScreen()),
      GoRoute(path: '/leads', builder: (_, __) => const LeadsScreen()),
      GoRoute(path: '/leads/new', builder: (_, __) => const PostLeadScreen()),
      GoRoute(path: '/deals', builder: (_, __) => const DealsScreen()),
      GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
      GoRoute(path: '/team', builder: (_, __) => const TeamScreen()),
      GoRoute(path: '/view-as', builder: (_, __) => const ViewAsScreen()),
      GoRoute(path: '/rentals', builder: (_, __) => const RentalsScreen()),
      GoRoute(path: '/maintenance', builder: (_, __) => const MaintenanceScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/soon/:title', builder: (_, st) => StubScreen(title: st.pathParameters['title']!)),

      // mortgages
      GoRoute(path: '/mortgages', builder: (_, __) => const MortgageListScreen()),
      GoRoute(path: '/mortgages/new', builder: (_, __) => const MortgageFormScreen()),
      GoRoute(path: '/mortgages/:id', builder: (_, s) => MortgageDetailScreen(id: s.pathParameters['id']!)),
    ],
  );
});
