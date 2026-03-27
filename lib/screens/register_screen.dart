import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
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

        // Voltar para tela de login
        Navigator.pop(context);
      } else {
        _mostrarMensagem('❌ Erro ao cadastrar. Tente novamente.',
            isError: true);
      }
    } catch (e) {
      _mostrarMensagem('Erro: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
      ),
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
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add,
                      size: 80,
                      color: Color(0xFF7B2CBF),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Criar Conta',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B2CBF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Preencha os dados para se cadastrar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Campo Nome
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: 'Nome (opcional)',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF7B2CBF), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF7B2CBF), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo Senha
                    TextField(
                      controller: _senhaController,
                      obscureText: !_mostrarSenha,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mostrarSenha
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _mostrarSenha = !_mostrarSenha),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF7B2CBF), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo Confirmar Senha
                    TextField(
                      controller: _confirmarController,
                      obscureText: !_mostrarConfirmar,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _mostrarConfirmar
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                              () => _mostrarConfirmar = !_mostrarConfirmar),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF7B2CBF), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão Cadastrar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _carregando ? null : _cadastrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2CBF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _carregando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'CADASTRAR',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Link para login
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Já tenho uma conta? Fazer login',
                        style: TextStyle(color: Color(0xFF7B2CBF)),
                      ),
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
