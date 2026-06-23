import '../models/profile.dart';
import 'supabase_service.dart';

class AuthService {
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    await supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _fetchProfile();
  }

  /// Self-registration for patients: creates Supabase auth user + profile row.
  /// Returns true if the session is established immediately (email confirmation
  /// disabled), or false if the user must confirm their email first.
  Future<bool> registerPatient({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final res = await supabaseClient.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': 'patient',
        'phone': phone,
      },
    );
    if (res.user == null) throw Exception('Registration failed — please try again.');
    // The on_auth_user_created trigger creates the profiles row automatically
    // using the metadata above. No client-side INSERT needed.
    return res.session != null;
  }

  Future<void> signOut() async {
    await supabaseClient.auth.signOut();
  }

  /// Returns the current user's profile, or null if not authenticated.
  Future<Profile?> currentProfile() async {
    if (supabaseClient.auth.currentUser == null) return null;
    return _fetchProfile();
  }

  Future<Profile> _fetchProfile() async {
    final userId = supabaseClient.auth.currentUser!.id;
    final data = await supabaseClient
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }
}
