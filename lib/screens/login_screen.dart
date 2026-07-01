// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html; // 🔥 LINHA MÁGICA
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../constants/app_colors.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final SyncService _syncService = SyncService();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;
  bool _mostrarSenha = false;

  Future<void> _fazerLogin() async {
    if (_loginController.text.isEmpty || _senhaController.text.isEmpty) {
      _mostrarMensagem('Preencha todos os campos', isError: true);
      return;
    }

    setState(() => _carregando = true);

    final usuario = await _auth.login(
      _loginController.text.trim(),
      _senhaController.text,
    );

    if (usuario != null && mounted) {
      _mostrarMensagem('✅ Login realizado!', isError: false);
      await _syncService.syncNow();
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      _mostrarMensagem('❌ Email/Usuário ou senha inválidos', isError: true);
    }

    setState(() => _carregando = false);
  }

  Future<void> _loginComGoogle() async {
    setState(() => _carregando = true);
    final usuario = await _auth.loginComGoogle();
    setState(() => _carregando = false);

    if (usuario != null && mounted) {
      _mostrarMensagem('✅ Login com Google realizado!', isError: false);
      await _syncService.syncNow();
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      _mostrarMensagem('❌ Erro ao fazer login com Google', isError: true);
    }
  }

  void _mostrarMensagem(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final bool isWindows = identical(0, 0.0) ? false : false;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF133B5C), Color(0xFF1B5F8C)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 0, vertical: 20),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    width: isMobile ? double.infinity : 420,
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Bem-vindo de volta!',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF343A40)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Faça login para continuar',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _loginController,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: 'E-mail ou Username',
                            hintText: 'seu@email.com ou username',
                            labelStyle:
                                const TextStyle(color: AppColors.primary),
                            prefixIcon: const Icon(Icons.person_outline,
                                color: AppColors.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _senhaController,
                          obscureText: !_mostrarSenha,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            hintText: '••••••••',
                            labelStyle:
                                const TextStyle(color: AppColors.primary),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppColors.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _mostrarSenha
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: AppColors.primary),
                              onPressed: () => setState(
                                  () => _mostrarSenha = !_mostrarSenha),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pushNamed(
                                context, '/forgot-password'),
                            child: const Text('Esqueceu a senha?',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _carregando
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary))
                            : SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _fazerLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    elevation: 3,
                                    shadowColor: AppColors.primary
                                        .withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                  child: const Text('ENTRAR',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ),
                              ),
                        if (!isWindows) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text('ou continue com',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12)),
                              ),
                              Expanded(
                                  child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _carregando ? null : _loginComGoogle,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/images/google_g.png',
                                      height: 24),
                                  const SizedBox(width: 12),
                                  const Text('Google',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF343A40))),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Não tem uma conta?',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13)),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/register'),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero),
                              child: const Text('CADASTRE-SE',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
