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
  Future<void> registerPatient({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final res = await supabaseClient.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    final userId = res.user?.id;
    if (userId == null) throw Exception('Registration failed — please try again.');

    // Upsert profile in case the trigger created a partial row already
    await supabaseClient.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'role': 'patient',
    });
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
