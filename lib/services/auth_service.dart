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
