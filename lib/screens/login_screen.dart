import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final SyncService _syncService = SyncService();
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

    if (usuario != null && mounted) {
      _mostrarMensagem('✅ Login realizado!', isError: false);
      await _syncService.syncNow();
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      _mostrarMensagem('❌ Email ou senha inválidos', isError: true);
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
    final bool isWindows = Platform.isWindows;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD), Color(0xFFE0AAFF)],
          ),
        ),
        child: Stack(
          children: [
            // 🔥 IMAGEM DE FUNDO (ESPALHADA, TRANSPARENTE)
            Container(
              width: double.infinity,
              height: double.infinity,
              child: Opacity(
                opacity: 0.15, // 🔥 Deixa a imagem transparente (15%)
                child: Image.asset(
                  'assets/images/login_illustration.png',
                  fit: BoxFit.cover, // 🔥 Espalha pela tela toda
                  errorBuilder: (context, error, stackTrace) {
                    return SizedBox.shrink(); // Some se não tiver imagem
                  },
                ),
              ),
            ),
            // 🔥 CARD BRANCO (por cima)
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 0, vertical: 20),
                child: FadeInUp(
                  duration: Duration(milliseconds: 800),
                  child: Container(
                    width: isMobile ? double.infinity : 420,
                    constraints: BoxConstraints(maxWidth: 450),
                    padding: EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bem-vindo de volta!',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF343A40)),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Faça login para continuar',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 32),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'E-mail',
                            hintText: 'seu@email.com',
                            labelStyle: TextStyle(color: Color(0xFF7B2CBF)),
                            prefixIcon: Icon(Icons.email_outlined,
                                color: Color(0xFF7B2CBF)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: Color(0xFF7B2CBF), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _senhaController,
                          obscureText: !_mostrarSenha,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            hintText: '••••••••',
                            labelStyle: TextStyle(color: Color(0xFF7B2CBF)),
                            prefixIcon: Icon(Icons.lock_outline,
                                color: Color(0xFF7B2CBF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _mostrarSenha
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Color(0xFF7B2CBF)),
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
                              borderSide: BorderSide(
                                  color: Color(0xFF7B2CBF), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pushNamed(
                                context, '/forgot-password'),
                            child: Text('Esqueceu a senha?',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF7B2CBF))),
                          ),
                        ),
                        SizedBox(height: 16),
                        _carregando
                            ? Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF7B2CBF)))
                            : SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _fazerLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF7B2CBF),
                                    elevation: 3,
                                    shadowColor:
                                        Color(0xFF7B2CBF).withOpacity(0.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                  child: Text('ENTRAR',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ),
                              ),
                        if (!isWindows) ...[
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('ou continue com',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12)),
                              ),
                              Expanded(
                                  child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          SizedBox(height: 16),
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
                                  Image.asset(
                                    'assets/images/google_g.png',
                                    height: 24,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Color(0xFF7B2CBF),
                                              width: 1),
                                        ),
                                        child: Center(
                                            child: Text('G',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF7B2CBF)))),
                                      );
                                    },
                                  ),
                                  SizedBox(width: 12),
                                  Text('Google',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF343A40))),
                                ],
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Não tem uma conta?',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13)),
                            SizedBox(width: 4),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/register'),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero),
                              child: Text('CADASTRE-SE',
                                  style: TextStyle(
                                      color: Color(0xFF7B2CBF),
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
