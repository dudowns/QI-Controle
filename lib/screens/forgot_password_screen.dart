// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import 'verify_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  bool _carregando = false;

  Future<void> _enviarRecuperacao() async {
    if (_emailController.text.isEmpty) {
      _mostrarMensagem('Digite seu e-mail', isError: true);
      return;
    }

    setState(() => _carregando = true);

    try {
      await _auth.resetPassword(_emailController.text.trim());
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                VerifyOtpScreen(email: _emailController.text.trim()),
          ),
        );
      }
    } catch (e) {
      _mostrarMensagem('Erro: $e', isError: true);
    } finally {
      setState(() => _carregando = false);
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD), Color(0xFFE0AAFF)],
          ),
        ),
        child: Center(
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
                    ElasticIn(
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2CBF)
                                  .withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_reset,
                            size: 50, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recuperar Senha',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF343A40)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Digite seu e-mail para receber um codigo',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        hintText: 'seu@email.com',
                        labelStyle: const TextStyle(color: Color(0xFF7B2CBF)),
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: Color(0xFF7B2CBF)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF7B2CBF), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _carregando
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF7B2CBF)))
                        : SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _enviarRecuperacao,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B2CBF),
                                elevation: 3,
                                shadowColor: const Color(0xFF7B2CBF)
                                    .withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('ENVIAR CODIGO',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('VOLTAR PARA LOGIN',
                          style: TextStyle(color: Color(0xFF7B2CBF))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
