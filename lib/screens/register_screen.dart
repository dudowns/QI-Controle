import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarController = TextEditingController();
  bool _carregando = false;
  bool _mostrarSenha = false;
  bool _mostrarConfirmar = false;

  Future<void> _cadastrar() async {
    if (_emailController.text.isEmpty) {
      _mostrarMensagem('Digite seu e-mail', isError: true);
      return;
    }
    if (_senhaController.text.isEmpty) {
      _mostrarMensagem('Digite sua senha', isError: true);
      return;
    }
    if (_senhaController.text.length < 6) {
      _mostrarMensagem('A senha deve ter no mínimo 6 caracteres',
          isError: true);
      return;
    }
    if (_senhaController.text != _confirmarController.text) {
      _mostrarMensagem('As senhas não coincidem', isError: true);
      return;
    }

    setState(() => _carregando = true);

    try {
      final usuario = await _auth.cadastrar(
        _emailController.text.trim(),
        _senhaController.text,
        _nomeController.text.isEmpty ? 'Usuário' : _nomeController.text.trim(),
      );

      if (usuario != null && mounted) {
        _mostrarMensagem('✅ Cadastro realizado! Faça login.', isError: false);
        Navigator.pop(context);
      } else {
        _mostrarMensagem('❌ Erro ao cadastrar. Tente novamente.',
            isError: true);
      }
    } catch (e) {
      _mostrarMensagem('Erro: $e', isError: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
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
                        child: Icon(Icons.person_add,
                            size: 50, color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Criar Conta',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF343A40)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Preencha os dados para se cadastrar',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 32),
                    // Nome
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: 'Nome (opcional)',
                        hintText: 'Seu nome',
                        labelStyle: TextStyle(color: Color(0xFF7B2CBF)),
                        prefixIcon: Icon(Icons.person_outline,
                            color: Color(0xFF7B2CBF)),
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
                    SizedBox(height: 16),
                    // Email
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
                          borderSide:
                              BorderSide(color: Color(0xFF7B2CBF), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    SizedBox(height: 16),
                    // Senha
                    TextField(
                      controller: _senhaController,
                      obscureText: !_mostrarSenha,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        hintText: '••••••••',
                        labelStyle: TextStyle(color: Color(0xFF7B2CBF)),
                        prefixIcon:
                            Icon(Icons.lock_outline, color: Color(0xFF7B2CBF)),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _mostrarSenha
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Color(0xFF7B2CBF)),
                          onPressed: () =>
                              setState(() => _mostrarSenha = !_mostrarSenha),
                        ),
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
                    SizedBox(height: 16),
                    // Confirmar Senha
                    TextField(
                      controller: _confirmarController,
                      obscureText: !_mostrarConfirmar,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Senha',
                        hintText: '••••••••',
                        labelStyle: TextStyle(color: Color(0xFF7B2CBF)),
                        prefixIcon:
                            Icon(Icons.lock_outline, color: Color(0xFF7B2CBF)),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _mostrarConfirmar
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Color(0xFF7B2CBF)),
                          onPressed: () => setState(
                              () => _mostrarConfirmar = !_mostrarConfirmar),
                        ),
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
                    // Botão Cadastrar
                    _carregando
                        ? Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF7B2CBF)))
                        : SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _cadastrar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF7B2CBF),
                                elevation: 3,
                                shadowColor: Color(0xFF7B2CBF).withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('CADASTRAR',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Já tem uma conta?',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                        SizedBox(width: 4),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero, minimumSize: Size.zero),
                          child: Text('FAZER LOGIN',
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
      ),
    );
  }
}
