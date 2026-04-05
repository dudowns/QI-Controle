import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';
import 'reset_password_screen.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _otpController = TextEditingController();
  bool _carregando = false;

  Future<void> _verificarCodigo() async {
    if (_otpController.text.isEmpty) {
      _mostrarMensagem('Digite o código', isError: true);
      return;
    }

    setState(() => _carregando = true);

    try {
      await _auth.verifyOtp(_otpController.text.trim(), widget.email);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
        );
      }
    } catch (e) {
      _mostrarMensagem('Código inválido ou expirado', isError: true);
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _mostrarMensagem(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
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
        decoration: BoxDecoration(
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
                    ElasticIn(
                      duration: Duration(milliseconds: 800),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF7B2CBF).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(Icons.pin, size: 50, color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Verificar Código',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF343A40)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enviamos um código para:\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 32),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '000000',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: Color(0xFF7B2CBF), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    SizedBox(height: 24),
                    _carregando
                        ? Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF7B2CBF)))
                        : SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _verificarCodigo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF7B2CBF),
                                elevation: 3,
                                shadowColor: Color(0xFF7B2CBF).withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('VERIFICAR CÓDIGO',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('VOLTAR',
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
