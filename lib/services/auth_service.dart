import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Verifica se está logado
  bool get estaLogado => _supabase.auth.currentSession != null;

  // Pega o usuário atual
  User? get usuarioAtual => _supabase.auth.currentUser;

  // Login com email/senha
  Future<User?> login(String email, String senha) async {
    try {
      print('🔐 Tentando login: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: senha,
      );

      print('✅ Login bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      print('❌ Erro no login: $e');
      return null;
    }
  }

  // Cadastro com email/senha
  Future<User?> cadastrar(String email, String senha, String nome) async {
    try {
      print('📝 Tentando cadastrar: $email');
      print('📝 Nome: $nome');

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: senha,
        data: {'name': nome.trim()},
      );

      if (response.user == null) {
        print('⚠️ Nenhum usuário retornado');
        return null;
      }

      print('✅ Cadastro bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      print('❌ Erro no cadastro: $e');
      return null;
    }
  }

  // Login com Google
  Future<User?> loginComGoogle() async {
    try {
      print('🔐 Tentando login com Google');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('⚠️ Login com Google cancelado');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );

      print('✅ Login Google bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      print('❌ Erro no login com Google: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
      print('✅ Logout realizado');
    } catch (e) {
      print('❌ Erro no logout: $e');
    }
  }
}
