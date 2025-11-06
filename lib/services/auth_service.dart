import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Verify OTP is valid and not used (before attempting login)
  Future<bool> verifyOtpNotUsed(String email, String otpCode) async {
    try {
      // Use admin client to check OTP status before login
      final response = await _adminSupabase
          .from('parent_otps')
          .select('id, is_used, expires_at, user_id')
          .eq('otp_code', otpCode)
          .eq('is_used', false)
          .maybeSingle();

      if (response == null) return false;

      // Check if OTP is expired
      final expiresAt = DateTime.parse(response['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) return false;

      // Verify the OTP belongs to a user with this email
      final userId = response['user_id'] as String;
      final userResponse = await _adminSupabase.auth.admin.getUserById(userId);
      if (userResponse.user?.email != email) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  // Mark the OTP as used after the password has been successfully set.
  Future<void> markOtpAsUsed() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return;
    }
    await _supabase
        .from('parent_otps')
        .update({'is_used': true})
        .eq('user_id', user.id)
        .eq('is_used', false); // Only update if not already used
  }

  // Admin client for privileged operations
  final SupabaseClient _adminSupabase = SupabaseClient(
    'https://nnjjefycskerdjqmatkf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uamplZnljc2tlcmRqcW1hdGtmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjYyNTQ3NiwiZXhwIjoyMDY4MjAxNDc2fQ.nGXxDihQI6LDVWi8M8rnYAcmHXaIZF2DvSfSITGMBmw',
  );

  // Create a school admin record (Superadmin only)
  Future<void> createSchoolAdmin(String userId, String schoolId) async {
    await _adminSupabase.from('school_admins').insert({
      'user_id': userId,
      'school_id': schoolId,
    });
  }

  // Invite a new user by email and assign a role (Superadmin only)
  // Optionally attach school metadata so it appears in Authentication -> Users (user_metadata)
  Future<User> inviteUserByEmail(
    String email,
    String role, {
    String? schoolName,
    String? schoolId,
    String redirectTo = 'http://localhost:3002',
  }) async {
    try {
      // Invite the user by email, passing the school name as custom data.
      final response = await _adminSupabase.auth.admin.inviteUserByEmail(
        email,
        // Redirect to the running School Admin app (web). Adjust in production.
        redirectTo: redirectTo,
        data: {
          'role': role,
          if (schoolName != null) 'school_name': schoolName,
          if (schoolId != null) 'school_id': schoolId,
        },
      );
      final newUser = response.user;

      if (newUser == null) {
        throw Exception('Failed to create user during invitation.');
      }

      // Update the user's metadata to include their role.
      await _adminSupabase.auth.admin.updateUserById(
        newUser.id,
        attributes: AdminUserAttributes(userMetadata: {
          'role': role,
          if (schoolId != null) 'school_id': schoolId,
          if (schoolName != null) 'school_name': schoolName,
        }),
      );

      return newUser;
    } catch (e) {
      // Provide a more specific error message.
      throw Exception('Failed to invite user: $e');
    }
  }

  // Get the current user session
  Session? get currentSession => _supabase.auth.currentSession;

  // Get a stream of authentication state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign in with email and password
  Future<void> signInWithPassword(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      // Handle specific auth errors, e.g., invalid login credentials
      throw Exception('Failed to sign in: ${e.message}');
    } catch (e) {
      // Handle other errors
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign out the current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }


  // Change user password
  Future<void> changePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

}
