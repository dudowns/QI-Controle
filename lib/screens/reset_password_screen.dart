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
            child: Icon(Icons.lock_outline, size: 50, color: Colors.white),
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Criar Nova Senha',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF343A40)),
        ),
        SizedBox(height: 8),
        Text(
          'Digite sua nova senha',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        SizedBox(height: 32),
        TextField(
          controller: _senhaController,
          obscureText: !_mostrarSenha,
          decoration: InputDecoration(
            labelText: 'Nova Senha',
            hintText: '••••••••',
            labelStyle: TextStyle(color: Color(0xFF7B2CBF)),
            prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF7B2CBF)),
            suffixIcon: IconButton(
              icon: Icon(
                  _mostrarSenha ? Icons.visibility : Icons.visibility_off,
                  color: Color(0xFF7B2CBF)),
              onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Color(0xFF7B2CBF), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _confirmarController,
          obscureText: !_mostrarConfirmar,
          decoration: InputDecoration(
            labelText: 'Confirmar Senha',
            hintText: '••••••••',
            labelStyle: TextStyle(color: Color(0xFF7B2CBF)),
            prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF7B2CBF)),
            suffixIcon: IconButton(
              icon: Icon(
                  _mostrarConfirmar ? Icons.visibility : Icons.visibility_off,
                  color: Color(0xFF7B2CBF)),
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
              borderSide: BorderSide(color: Color(0xFF7B2CBF), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        SizedBox(height: 24),
        _carregando
            ? Center(child: CircularProgressIndicator(color: Color(0xFF7B2CBF)))
            : SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _atualizarSenha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF7B2CBF),
                    elevation: 3,
                    shadowColor: Color(0xFF7B2CBF).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('ALTERAR SENHA',
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
        Icon(Icons.check_circle, size: 80, color: Colors.green),
        SizedBox(height: 24),
        Text(
          'Senha Alterada!',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        SizedBox(height: 8),
        Text(
          'Sua senha foi alterada com sucesso.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/', (route) => false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7B2CBF),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('VOLTAR PARA LOGIN',
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
