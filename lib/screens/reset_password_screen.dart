import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarController = TextEditingController();
  bool _carregando = false;
  bool _mostrarSenha = false;
  bool _mostrarConfirmar = false;
  bool _senhaAlterada = false;

  Future<void> _atualizarSenha() async {
    if (_senhaController.text.isEmpty) {
      _mostrarMensagem('Digite sua nova senha', isError: true);
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
      await _auth.updatePassword(_senhaController.text);
      setState(() {
        _senhaAlterada = true;
        _carregando = false;
      });
    } catch (e) {
      _mostrarMensagem('Erro: $e', isError: true);
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
                  color: Colors.white.withValues(alpha:0.95),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child:
                    _senhaAlterada ? _buildSuccessWidget() : _buildFormWidget(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormWidget() {
    return Column(
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
                  color: const Color(0xFF7B2CBF).withValues(alpha:0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.lock_outline, size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Criar Nova Senha',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF343A40)),
        ),
        const SizedBox(height: 8),
        Text(
          'Digite sua nova senha',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _senhaController,
          obscureText: !_mostrarSenha,
          decoration: InputDecoration(
            labelText: 'Nova Senha',
            hintText: '••••••••',
            labelStyle: const TextStyle(color: Color(0xFF7B2CBF)),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF7B2CBF)),
            suffixIcon: IconButton(
              icon: Icon(
                  _mostrarSenha ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF7B2CBF)),
              onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmarController,
          obscureText: !_mostrarConfirmar,
          decoration: InputDecoration(
            labelText: 'Confirmar Senha',
            hintText: '••••••••',
            labelStyle: const TextStyle(color: Color(0xFF7B2CBF)),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF7B2CBF)),
            suffixIcon: IconButton(
              icon: Icon(
                  _mostrarConfirmar ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF7B2CBF)),
              onPressed: () =>
                  setState(() => _mostrarConfirmar = !_mostrarConfirmar),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        const SizedBox(height: 24),
        _carregando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B2CBF)))
            : SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _atualizarSenha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    elevation: 3,
                    shadowColor: const Color(0xFF7B2CBF).withValues(alpha:0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('ALTERAR SENHA',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
      ],
    );
  }

  Widget _buildSuccessWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        const Text(
          'Senha Alterada!',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sua senha foi alterada com sucesso.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/', (route) => false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('VOLTAR PARA LOGIN',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

