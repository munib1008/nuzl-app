import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/listings/presentation/listings_screen.dart';
import '../../features/leads/presentation/leads_screen.dart';
import '../../features/deals/presentation/deals_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/mortgage/presentation/calculator_screen.dart';
import '../../features/mortgage/presentation/mortgage_list_screen.dart';
import '../../features/mortgage/presentation/mortgage_form_screen.dart';
import '../../features/mortgage/presentation/mortgage_detail_screen.dart';
import '../../features/landing/landing_screen.dart';
import '../../features/marketing/info_page.dart';
import '../../features/shell/main_shell.dart';
import '../network/api_client.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
    _ref.listen(unauthorizedProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

/// Public routes accessible without login (the mortgage calculator included).
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
      if (state.matchedLocation == '/' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register') {
        return '/feed';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      // public calculator
      GoRoute(path: '/calculator', builder: (_, __) => const CalculatorScreen()),
      GoRoute(path: '/info/:slug', builder: (_, st) => InfoPage(slug: st.pathParameters['slug']!)),
      // authed mortgage tracker (pushed routes, not bottom-nav tabs)
      GoRoute(path: '/mortgages', builder: (_, __) => const MortgageListScreen()),
      GoRoute(path: '/mortgages/new', builder: (_, __) => const MortgageFormScreen()),
      GoRoute(path: '/mortgages/:id',
          builder: (_, s) => MortgageDetailScreen(id: s.pathParameters['id']!)),
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/properties', builder: (_, __) => const ListingsScreen()),
          GoRoute(path: '/leads', builder: (_, __) => const LeadsScreen()),
          GoRoute(path: '/deals', builder: (_, __) => const DealsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
