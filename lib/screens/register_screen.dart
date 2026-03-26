import 'package:flutter/material.dart';
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
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  bool _carregando = false;
  bool _mostrarSenha = false;
  bool _mostrarConfirmarSenha = false;

  Future<void> _fazerCadastro() async {
    // Validações
    if (_nomeController.text.isEmpty) {
      _mostrarMensagem('Digite seu nome', isError: true);
      return;
    }
    if (_emailController.text.isEmpty) {
      _mostrarMensagem('Digite seu email', isError: true);
      return;
    }
    if (!_emailController.text.contains('@')) {
      _mostrarMensagem('Email inválido', isError: true);
      return;
    }
    if (_senhaController.text.length < 6) {
      _mostrarMensagem('A senha deve ter pelo menos 6 caracteres',
          isError: true);
      return;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      _mostrarMensagem('As senhas não coincidem', isError: true);
      return;
    }

    setState(() => _carregando = true);

    try {
      final usuario = await _auth.cadastrar(
        _emailController.text.trim(),
        _senhaController.text,
        _nomeController.text.trim(),
      );

      setState(() => _carregando = false);

      if (usuario != null && mounted) {
        _mostrarMensagem('✅ Conta criada com sucesso!', isError: false);
        // Aguarda 2 segundos e volta para login
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _mostrarMensagem('❌ Erro ao criar conta. Tente outro email.',
            isError: true);
      }
    } catch (e) {
      setState(() => _carregando = false);
      _mostrarMensagem('❌ Erro: ${e.toString()}', isError: true);
    }
  }

  void _mostrarMensagem(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFF7B2CBF), // ROXO escuro
              Color(0xFF9D4EDD), // ROXO médio
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add,
                    size: 60,
                    color: Color(0xFF7B2CBF),
                  ),
                ),
                const SizedBox(height: 32),

                // Título
                const Text(
                  'Criar Conta',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preencha os dados para começar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),

                // Card branco com formulário
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
                      // Nome
                      TextField(
                        controller: _nomeController,
                        decoration: InputDecoration(
                          labelText: 'Nome completo',
                          labelStyle: const TextStyle(color: Color(0xFF7B2CBF)),
                          prefixIcon: const Icon(Icons.person_outline,
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

                      // Email
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

                      // Senha
                      TextField(
                        controller: _senhaController,
                        obscureText: !_mostrarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha (mínimo 6 caracteres)',
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
                      const SizedBox(height: 16),

                      // Confirmar senha
                      TextField(
                        controller: _confirmarSenhaController,
                        obscureText: !_mostrarConfirmarSenha,
                        decoration: InputDecoration(
                          labelText: 'Confirmar senha',
                          labelStyle: const TextStyle(color: Color(0xFF7B2CBF)),
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: Color(0xFF7B2CBF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _mostrarConfirmarSenha
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Color(0xFF7B2CBF),
                            ),
                            onPressed: () => setState(() =>
                                _mostrarConfirmarSenha =
                                    !_mostrarConfirmarSenha),
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
                      const SizedBox(height: 24),

                      // Botão Cadastrar
                      _carregando
                          ? const CircularProgressIndicator(
                              color: Color(0xFF7B2CBF))
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _fazerCadastro,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7B2CBF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'CADASTRAR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Link login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Já tem uma conta?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'FAZER LOGIN',
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
