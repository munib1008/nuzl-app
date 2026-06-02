import 'package:google_sign_in/google_sign_in.dart';
import '../config/google_config.dart';

/// Returns a Google ID token to exchange with the API (POST /auth/google),
/// or null if the user cancels.
class GoogleSignInService {
  Future<String?> getIdToken() async {
    final gsi = GoogleSignIn(
      scopes: const ['email', 'profile'],
      clientId: googleWebClientId.isEmpty ? null : googleWebClientId,
    );
    final account = await gsi.signIn();
    if (account == null) return null; // cancelled
    final auth = await account.authentication;
    return auth.idToken;
  }
}
