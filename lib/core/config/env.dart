/// Runtime configuration.
///
/// The app talks to the NestJS API (not Supabase directly). Override the API
/// base at build/run time:
///   flutter run --dart-define=API_BASE_URL=https://your-api-host/api
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  // Supabase project (public values). Used by the API for storage uploads and
  // the DB connection. Kept here for reference / optional direct-Supabase use.
  // NOTE: you pasted two different project refs — confirm which is correct.
  static const supabaseUrl = 'https://islwoaccgrwwchzavppn.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_1QzY4VVF_vWc9n6siAQAlg_GHUWANCZ';
}
