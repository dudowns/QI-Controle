import 'package:flutter/material.dart';
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Senha'),
        backgroundColor: const Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
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
        const Icon(
          Icons.lock_outline,
          size: 80,
          color: Color(0xFF7B2CBF),
        ),
        const SizedBox(height: 16),
        const Text(
          'Criar Nova Senha',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7B2CBF),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Digite sua nova senha',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _senhaController,
          obscureText: !_mostrarSenha,
          decoration: InputDecoration(
            labelText: 'Nova Senha',
            prefixIcon:
                const Icon(Icons.lock_outline, color: Color(0xFF7B2CBF)),
            suffixIcon: IconButton(
              icon: Icon(
                _mostrarSenha ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF7B2CBF),
              ),
              onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmarController,
          obscureText: !_mostrarConfirmar,
          decoration: InputDecoration(
            labelText: 'Confirmar Senha',
            prefixIcon:
                const Icon(Icons.lock_outline, color: Color(0xFF7B2CBF)),
            suffixIcon: IconButton(
              icon: Icon(
                _mostrarConfirmar ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF7B2CBF),
              ),
              onPressed: () =>
                  setState(() => _mostrarConfirmar = !_mostrarConfirmar),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _carregando ? null : _atualizarSenha,
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
                    'ALTERAR SENHA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle,
          size: 80,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        const Text(
          'Senha Alterada!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sua senha foi alterada com sucesso.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'VOLTAR PARA LOGIN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
