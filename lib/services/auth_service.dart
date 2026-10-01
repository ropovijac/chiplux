import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;

  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  // =====================================================
  // USERNAME AVAILABILITY
  // =====================================================

  Future<Map<String, dynamic>> checkUsernameAvailability(
    String username,
  ) async {
    final normalized = username.trim().toLowerCase();

    final result = await client.rpc(
      'check_username_availability',
      params: {'p_username': normalized},
    );

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw Exception('Could not check username.');
  }

  // =====================================================
  // SIGN UP
  // =====================================================

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();

    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(normalizedUsername)) {
      throw const AuthException(
        'Username must contain 3–20 letters, numbers, or underscores.',
      );
    }

    // Recheck immediately before signup.
    // The database still provides the
    // final uniqueness guarantee.
    final availability = await checkUsernameAvailability(normalizedUsername);

    if (availability['available'] != true) {
      throw const AuthException('That username is already taken.');
    }

    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,

      // Supabase stores this in
      // auth.users.raw_user_meta_data.
      //
      // Our database trigger claims
      // the username at account creation.
      data: {'username': normalizedUsername},
    );

    // If email confirmation is disabled,
    // the account is immediately logged in.
    if (response.session != null) {
      await _syncSignupUsernameToProfile();
    }

    return response;
  }

  // =====================================================
  // SIGN IN
  //
  // identifier can be:
  //
  // email@example.com
  //
  // OR
  //
  // robert
  // =====================================================

  Future<AuthResponse> signIn({
    required String identifier,
    required String password,
  }) async {
    final value = identifier.trim();

    if (value.isEmpty) {
      throw const AuthException('Enter your email or username.');
    }

    late final AuthResponse response;

    // =========================================
    // EMAIL
    // =========================================

    if (value.contains('@')) {
      response = await client.auth.signInWithPassword(
        email: value,
        password: password,
      );
    }
    // =========================================
    // USERNAME
    // =========================================
    else {
      final username = value.toLowerCase();

      final functionResponse = await client.functions.invoke(
        'super-api',

        body: {'username': username, 'password': password},
      );

      final raw = functionResponse.data;

      if (raw is! Map) {
        throw const AuthException('Invalid username or password.');
      }

      final data = Map<String, dynamic>.from(raw);

      final refreshToken = data['refresh_token']?.toString();

      final accessToken = data['access_token']?.toString();

      if (refreshToken == null || refreshToken.isEmpty) {
        final error = data['error']?.toString();

        throw AuthException(error ?? 'Invalid username or password.');
      }

      response = await client.auth.setSession(
        refreshToken,

        accessToken: accessToken,
      );
    }

    await _syncSignupUsernameToProfile();

    return response;
  }

  // =====================================================
  // SYNC NEW SIGNUP USERNAME TO PROFILE
  //
  // Existing usernames are NEVER overwritten.
  // =====================================================

  Future<void> _syncSignupUsernameToProfile() async {
    final user = client.auth.currentUser;

    if (user == null) {
      return;
    }

    final metadataUsername = user.userMetadata?['username']
        ?.toString()
        .trim()
        .toLowerCase();

    if (metadataUsername == null || metadataUsername.isEmpty) {
      return;
    }

    try {
      final profile = await client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        return;
      }

      final currentUsername = profile['username']?.toString().trim() ?? '';

      // IMPORTANT:
      // An existing username is never
      // replaced here.
      if (currentUsername.isNotEmpty) {
        return;
      }

      await client
          .from('profiles')
          .update({'username': metadataUsername})
          .eq('id', user.id);
    } catch (_) {
      // Profile synchronization should
      // never prevent a valid login.
    }
  }

  // =====================================================
  // SIGN OUT
  // =====================================================

  Future<void> signOut() {
    return client.auth.signOut();
  }
}
