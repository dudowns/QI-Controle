import '../services/logger_service.dart';
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
      LoggerService.info('🔐 Tentando login: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: senha,
      );

      LoggerService.info('✅ Login bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      LoggerService.info('❌ Erro no login: $e');
      return null;
    }
  }

  // Cadastro com email/senha
  Future<User?> cadastrar(String email, String senha, String nome) async {
    try {
      LoggerService.info('📝 Tentando cadastrar: $email');

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: senha,
        data: {'name': nome.trim()},
      );

      if (response.user == null) {
        LoggerService.info('⚠️ Nenhum usuário retornado');
        return null;
      }

      LoggerService.info('✅ Cadastro bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      LoggerService.info('❌ Erro no cadastro: $e');
      return null;
    }
  }

  // 🔥 RECUPERAR SENHA - Envia email com link
  Future<void> resetPassword(String email) async {
    try {
      LoggerService.info('📧 Enviando recuperação de senha para: $email');
      await _supabase.auth.resetPasswordForEmail(email);
      LoggerService.info('✅ Email de recuperação enviado!');
    } catch (e) {
      LoggerService.info('❌ Erro ao enviar recuperação: $e');
      rethrow;
    }
  }

  // 🔥 NOVO: Atualizar senha (usado após recuperação)
  Future<void> updatePassword(String novaSenha) async {
    try {
      LoggerService.info('🔑 Atualizando senha...');
      await _supabase.auth.updateUser(
        UserAttributes(password: novaSenha),
      );
      LoggerService.info('✅ Senha atualizada com sucesso!');
    } catch (e) {
      LoggerService.info('❌ Erro ao atualizar senha: $e');
      rethrow;
    }
  }

  // 🔥 NOVO: Verificar OTP (código de 6 dígitos)
  Future<void> verifyOtp(String code, String email) async {
    try {
      LoggerService.info('🔐 Verificando OTP para: $email');
      await _supabase.auth.verifyOTP(
        type: OtpType.recovery,
        token: code,
        email: email,
      );
      LoggerService.info('✅ OTP verificado com sucesso!');
    } catch (e) {
      LoggerService.info('❌ Erro ao verificar OTP: $e');
      rethrow;
    }
  }

  // Login com Google
  Future<User?> loginComGoogle() async {
    try {
      LoggerService.info('🔐 Tentando login com Google');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        LoggerService.info('⚠️ Login com Google cancelado');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );

      LoggerService.info('✅ Login Google bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      LoggerService.info('❌ Erro no login com Google: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
      LoggerService.info('✅ Logout realizado');
    } catch (e) {
      LoggerService.info('❌ Erro no logout: $e');
    }
  }
}

