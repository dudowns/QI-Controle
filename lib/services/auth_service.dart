// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

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
      debugPrint('🔐 Tentando login: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: senha,
      );

      debugPrint('✅ Login bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      debugPrint('❌ Erro no login: $e');
      return null;
    }
  }

  // Cadastro com email/senha
  Future<User?> cadastrar(String email, String senha, String nome) async {
    try {
      debugPrint('📝 Tentando cadastrar: $email');

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: senha,
        data: {'name': nome.trim()},
      );

      if (response.user == null) {
        debugPrint('⚠️ Nenhum usuário retornado');
        return null;
      }

      debugPrint('✅ Cadastro bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      debugPrint('❌ Erro no cadastro: $e');
      return null;
    }
  }

  // 🔥 RECUPERAR SENHA - Envia email com link
  Future<void> resetPassword(String email) async {
    try {
      debugPrint('📧 Enviando recuperação de senha para: $email');
      await _supabase.auth.resetPasswordForEmail(email);
      debugPrint('✅ Email de recuperação enviado!');
    } catch (e) {
      debugPrint('❌ Erro ao enviar recuperação: $e');
      rethrow;
    }
  }

  // 🔥 NOVO: Atualizar senha (usado após recuperação)
  Future<void> updatePassword(String novaSenha) async {
    try {
      debugPrint('🔑 Atualizando senha...');
      await _supabase.auth.updateUser(
        UserAttributes(password: novaSenha),
      );
      debugPrint('✅ Senha atualizada com sucesso!');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar senha: $e');
      rethrow;
    }
  }

  // 🔥 NOVO: Verificar OTP (código de 6 dígitos)
  Future<void> verifyOtp(String code, String email) async {
    try {
      debugPrint('🔐 Verificando OTP para: $email');
      await _supabase.auth.verifyOTP(
        type: OtpType.recovery,
        token: code,
        email: email,
      );
      debugPrint('✅ OTP verificado com sucesso!');
    } catch (e) {
      debugPrint('❌ Erro ao verificar OTP: $e');
      rethrow;
    }
  }

  // Login com Google
  Future<User?> loginComGoogle() async {
    try {
      debugPrint('🔐 Tentando login com Google');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ Login com Google cancelado');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );

      debugPrint('✅ Login Google bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      debugPrint('❌ Erro no login com Google: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
      debugPrint('✅ Logout realizado');
    } catch (e) {
      debugPrint('❌ Erro no logout: $e');
    }
  }
}
