// lib/screens/login_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'register_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;
  bool _mostrarSenha = false;

  Future<void> _fazerLogin() async {
    if (_emailController.text.isEmpty || _senhaController.text.isEmpty) {
      _mostrarMensagem('Preencha email e senha', isError: true);
      return;
    }

    setState(() => _carregando = true);

    final usuario = await _auth.login(
      _emailController.text.trim(),
      _senhaController.text,
    );

    setState(() => _carregando = false);

    if (usuario != null && mounted) {
      _mostrarMensagem('✅ Login realizado!', isError: false);
      Navigator.pushReplacementNamed(context, '/');
    } else {
      _mostrarMensagem('❌ Email ou senha inválidos', isError: true);
    }
  }

  Future<void> _loginComGoogle() async {
    setState(() => _carregando = true);
    final usuario = await _auth.loginComGoogle();
    setState(() => _carregando = false);

    if (usuario != null && mounted) {
      _mostrarMensagem('✅ Login com Google realizado!', isError: false);
      Navigator.pushReplacementNamed(context, '/');
    } else {
      _mostrarMensagem('❌ Erro ao fazer login com Google', isError: true);
    }
  }

  void _mostrarMensagem(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWindows = Platform.isWindows;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFF7B2CBF),
              Color(0xFF9D4EDD),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 60,
                    color: Color(0xFF7B2CBF),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Controle Financeiro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Faça login para continuar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          labelStyle: const TextStyle(color: Color(0xFF7B2CBF)),
                          prefixIcon: const Icon(Icons.email_outlined,
                              color: Color(0xFF7B2CBF)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF7B2CBF)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF7B2CBF), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _senhaController,
                        obscureText: !_mostrarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          labelStyle: const TextStyle(color: Color(0xFF7B2CBF)),
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: Color(0xFF7B2CBF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _mostrarSenha
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Color(0xFF7B2CBF),
                            ),
                            onPressed: () =>
                                setState(() => _mostrarSenha = !_mostrarSenha),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF7B2CBF)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF7B2CBF), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 🔥 BOTÃO ESQUECI MINHA SENHA - ABRE A TELA
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _carregando
                              ? null
                              : () {
                                  Navigator.pushNamed(
                                      context, '/forgot-password');
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF7B2CBF),
                          ),
                          child: const Text(
                            'Esqueci minha senha?',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Botão Entrar
                      _carregando
                          ? const CircularProgressIndicator(
                              color: Color(0xFF7B2CBF))
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _fazerLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7B2CBF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'ENTRAR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                      if (!isWindows) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('ou',
                                  style:
                                      TextStyle(color: Colors.grey.shade500)),
                            ),
                            Expanded(
                                child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _carregando ? null : _loginComGoogle,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Image.asset(
                                'assets/images/google_g.png',
                                height: 30,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF7B2CBF),
                                          width: 1),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7B2CBF),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Não tem uma conta?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        'CADASTRE-SE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
