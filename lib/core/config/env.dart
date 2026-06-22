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

  // Supabase project (public values). The app talks to the NestJS API, not
  // Supabase directly — these are kept for reference / optional direct use.
  // Project: "nuzl testing" (ref xqdayltlwymckzkmnven). The API's DATABASE_URL /
  // SUPABASE_URL must point at this same project.
  static const supabaseUrl = 'https://xqdayltlwymckzkmnven.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_pJvVM-_mOfsUqjSVOa16JQ_jXdyTxvj';
}
