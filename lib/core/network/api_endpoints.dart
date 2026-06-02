/// Central list of API paths (relative to Env.apiBaseUrl). Mirrors the NestJS routes.
class Api {
  // auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const google = '/auth/google';
  // users
  static const me = '/users/me';
  static const theme = '/users/me/theme';
  // feed
  static const feed = '/feed';
  // listings
  static const listings = '/listings';
  static String listing(String id) => '/listings/$id';
  static String verifyListing(String id) => '/listings/$id/verify';
  // buyer requirements (leads)
  static const buyerRequirements = '/buyer-requirements';
  static String qualify(String id) => '/buyer-requirements/$id/qualify';
  // offers / deals
  static const offers = '/offers';
  // notifications
  static const notifications = '/notifications';
}
