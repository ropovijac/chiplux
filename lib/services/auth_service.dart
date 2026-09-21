import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance =
      AuthService._();

  SupabaseClient get client =>
      Supabase.instance.client;

  User? get currentUser =>
      client.auth.currentUser;

  Stream<AuthState> get authChanges =>
      client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return client.auth.signOut();
  }
}