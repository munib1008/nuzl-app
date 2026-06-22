/// Central list of API paths (relative to Env.apiBaseUrl). Mirrors the NestJS routes.
class Api {
  // auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const google = '/auth/google';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const publicListings = '/public/listings';
  // users
  static const me = '/users/me';
  static const theme = '/users/me/theme';
  // feed
  static const feed = '/feed';
  // listings
  static const listings = '/listings';
  static String listing(String id) => '/listings/$id';
  static String verifyListing(String id) => '/listings/$id/verify';
  static String publishListing(String id) => '/listings/$id/publish';
  static String unpublishListing(String id) => '/listings/$id/unpublish';
  static String listingAmenities(String id) => '/listings/$id/amenities';
  static const amenities = '/public/amenities';
  // saved searches + alerts
  static const savedSearches = '/saved-searches';
  static String savedSearch(String id) => '/saved-searches/$id';
  static const savedSearchAlerts = '/saved-searches/alerts';
  static const savedSearchAlertsSeen = '/saved-searches/alerts/seen';
  // buyer requirements (leads)
  static const buyerRequirements = '/buyer-requirements';
  static String qualify(String id) => '/buyer-requirements/$id/qualify';
  // offers / deals
  static const offers = '/offers';
  // notifications
  static const notifications = '/notifications';
}
