import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Supabase initialization and provides access to the shared client.
/// This is the ONLY place sub-apps should get their Supabase client from —
/// never instantiate Supabase directly inside apps/*.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Call once at app boot, before runApp(). Must complete before
  /// anything touches Supabase.instance.client.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'YOUR_SUPABASE_PROJECT_URL',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'YOUR_SUPABASE_ANON_KEY',
      ),
    );
  }

  /// Current session, or null if guest / not logged in.
  static Session? get currentSession => client.auth.currentSession;

  static bool get isLoggedIn => currentSession != null;
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;
}
