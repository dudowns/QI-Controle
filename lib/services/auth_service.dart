// lib/services/auth_service.dart
import '../services/logger_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool get estaLogado => _supabase.auth.currentSession != null;
  User? get usuarioAtual => _supabase.auth.currentUser;

  // ✅ Buscar perfil do usuário
  Future<Map<String, dynamic>?> getPerfil() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return response;
    } catch (e) {
      LoggerService.info('Erro ao buscar perfil: $e');
      return null;
    }
  }

  // ✅ Login com email OU username (busca email pelo username na tabela profiles)
  Future<User?> login(String emailOuUsername, String senha) async {
    try {
      LoggerService.info('🔐 Tentando login: $emailOuUsername');

      String email = emailOuUsername.trim();

      // Se NÃO parece email, busca o email pelo username na tabela profiles
      if (!emailOuUsername.contains('@')) {
        try {
          final response = await _supabase
              .from('profiles')
              .select('email')
              .eq('username', emailOuUsername.trim().toLowerCase())
              .maybeSingle();

          if (response != null && response['email'] != null) {
            email = response['email'] as String;
            LoggerService.info('✅ Username encontrado, email: $email');
          } else {
            LoggerService.info('⚠️ Username não encontrado: $emailOuUsername');
            return null;
          }
        } catch (e) {
          LoggerService.info('⚠️ Erro ao buscar username: $e');
          return null;
        }
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      LoggerService.info('✅ Login bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      LoggerService.info('❌ Erro no login: $e');
      return null;
    }
  }

  // ✅ Cadastro com username
  Future<User?> cadastrar(String email, String senha, String nome,
      {String? username}) async {
    try {
      LoggerService.info('📝 Tentando cadastrar: $email');

      // Verifica se username já existe
      if (username != null && username.isNotEmpty) {
        final existente = await _supabase
            .from('profiles')
            .select('id')
            .eq('username', username.toLowerCase().trim())
            .maybeSingle();

        if (existente != null) {
          LoggerService.info('⚠️ Username já existe: $username');
          throw Exception('Este nome de usuário já está em uso');
        }
      }

      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: senha,
        data: {'name': nome.trim()},
      );

      if (response.user == null) {
        LoggerService.info('⚠️ Nenhum usuário retornado');
        return null;
      }

      // Cria perfil com username e email
      if (username != null && username.isNotEmpty) {
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'username': username.toLowerCase().trim(),
          'nome': nome.trim(),
          'email': email.trim(),
        });
        LoggerService.info('✅ Perfil criado com username: $username');
      }

      LoggerService.info('✅ Cadastro bem-sucedido: ${response.user?.email}');
      return response.user;
    } catch (e) {
      LoggerService.info('❌ Erro no cadastro: $e');
      rethrow;
    }
  }

  // Recuperar senha
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

  // Atualizar senha
  Future<void> updatePassword(String novaSenha) async {
    try {
      LoggerService.info('🔑 Atualizando senha...');
      await _supabase.auth.updateUser(UserAttributes(password: novaSenha));
      LoggerService.info('✅ Senha atualizada com sucesso!');
    } catch (e) {
      LoggerService.info('❌ Erro ao atualizar senha: $e');
      rethrow;
    }
  }

  // Verificar OTP
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
      LoggerService.info(
          '✅ Login Google bem-sucedido: ${response.user?.email}');
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
