// lib/screens/configuracoes_screen.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/theme_service.dart';
import '../services/storage_service.dart';
import '../constants/app_colors.dart';
import '../widgets/toast.dart';
import '../services/logger_service.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final AuthService _auth = AuthService();
  final SyncService _syncService = SyncService();
  final StorageService _storageService = StorageService();
  final _supabase = Supabase.instance.client;

  final _usernameController = TextEditingController();
  final _nomeController = TextEditingController();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _pinConfigController = TextEditingController();

  Map<String, dynamic>? _perfil;
  bool _carregando = true;
  bool _salvandoPerfil = false;
  bool _alterandoSenha = false;
  bool _salvandoPin = false;
  bool _mostrarSenhaAtual = false;
  bool _mostrarSenhaNova = false;
  bool _mostrarPin = false;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    setState(() => _carregando = true);
    try {
      _perfil = await _auth.getPerfil();
      if (_perfil != null) {
        _usernameController.text = _perfil!['username'] ?? '';
        _nomeController.text = _perfil!['nome'] ?? '';
        _pinConfigController.text = _perfil!['pin'] ?? '';
      }
    } catch (e) {
      LoggerService.error('Erro ao carregar perfil: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvarPerfil() async {
    final username = _usernameController.text.trim().toLowerCase();
    final nome = _nomeController.text.trim();
    if (username.isEmpty) {
      Toast.warning(context, 'Digite um username');
      return;
    }

    setState(() => _salvandoPerfil = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final existente = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .neq('id', user.id)
          .maybeSingle();
      if (existente != null) {
        Toast.warning(context, 'Username já em uso!');
        return;
      }

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'nome': nome,
        'email': user.email,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await _carregarPerfil();
      Toast.success(context, '✅ Perfil atualizado!');
    } catch (e) {
      Toast.error(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvandoPerfil = false);
    }
  }

  Future<void> _salvarPin() async {
    final pin = _pinConfigController.text.trim();
    if (pin.isEmpty) {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('profiles')
            .update({'pin': null}).eq('id', user.id);
        Toast.success(context, '✅ PIN removido!');
      }
      return;
    }
    if (pin.length != 4 || int.tryParse(pin) == null) {
      Toast.warning(context, 'Digite um PIN de 4 dígitos');
      return;
    }

    setState(() => _salvandoPin = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase.from('profiles').update({'pin': pin}).eq('id', user.id);
      Toast.success(context, '✅ PIN salvo!');
    } catch (e) {
      Toast.error(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _salvandoPin = false);
    }
  }

  Future<void> _alterarSenha() async {
    if (_senhaAtualController.text.isEmpty) {
      Toast.warning(context, 'Digite a senha atual');
      return;
    }
    if (_novaSenhaController.text.length < 6) {
      Toast.warning(context, 'Mínimo 6 caracteres');
      return;
    }
    if (_novaSenhaController.text != _confirmarSenhaController.text) {
      Toast.warning(context, 'Senhas não coincidem');
      return;
    }

    setState(() => _alterandoSenha = true);
    try {
      await _auth.updatePassword(_novaSenhaController.text);
      Toast.success(context, '✅ Senha alterada!');
      _senhaAtualController.clear();
      _novaSenhaController.clear();
      _confirmarSenhaController.clear();
    } catch (e) {
      Toast.error(context, 'Erro ao alterar: $e');
    } finally {
      if (mounted) setState(() => _alterandoSenha = false);
    }
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    try {
      await _syncService.syncNow();
      Toast.success(context, '✅ Sincronizado!');
    } catch (e) {
      Toast.error(context, 'Erro ao sincronizar: $e');
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Future<void> _logout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sair', style: TextStyle(color: Colors.white)))
        ],
      ),
    );
    if (confirmar == true) {
      await _auth.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/profiles', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text('Configurações',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                // ✅ FOTO DE PERFIL
                FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: _buildFotoPerfil()),
                const SizedBox(height: 10),

                // SEÇÃO PERFIL
                FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: _buildCard(
                        icon: Icons.person_outline,
                        title: 'Perfil',
                        children: [
                          _buildTextField(_usernameController, 'Username',
                              Icons.alternate_email,
                              hint: 'seu_username'),
                          const SizedBox(height: 8),
                          _buildTextField(
                              _nomeController, 'Nome', Icons.badge_outlined,
                              hint: 'Seu nome'),
                          const SizedBox(height: 8),
                          _buildEmailRow(),
                          const SizedBox(height: 10),
                          _buildButton(
                              'Salvar Perfil',
                              Icons.save,
                              _salvandoPerfil,
                              _salvarPerfil,
                              AppColors.primary),
                        ])),
                const SizedBox(height: 10),

                // SEÇÃO PIN
                FadeInUp(
                    duration: const Duration(milliseconds: 450),
                    child: _buildCard(
                        icon: Icons.pin,
                        title: 'PIN de Acesso',
                        children: [
                          Text(
                              'Configure um PIN de 4 dígitos para acessar rapidamente pela tela de perfis.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context))),
                          const SizedBox(height: 10),
                          _buildTextField(_pinConfigController,
                              'PIN (4 dígitos)', Icons.dialpad,
                              hint: '0000',
                              maxLength: 4,
                              keyboardType: TextInputType.number,
                              isPassword: true,
                              showPassword: _mostrarPin,
                              onToggle: () =>
                                  setState(() => _mostrarPin = !_mostrarPin)),
                          const SizedBox(height: 10),
                          _buildButton('Salvar PIN', Icons.lock, _salvandoPin,
                              _salvarPin, Colors.amber.shade700),
                        ])),
                const SizedBox(height: 10),

                // SEÇÃO SENHA
                FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: _buildCard(
                        icon: Icons.lock_outline,
                        title: 'Alterar Senha',
                        children: [
                          _buildTextField(
                              _senhaAtualController, 'Senha atual', Icons.lock,
                              isPassword: true,
                              showPassword: _mostrarSenhaAtual,
                              onToggle: () => setState(() =>
                                  _mostrarSenhaAtual = !_mostrarSenhaAtual)),
                          const SizedBox(height: 8),
                          _buildTextField(_novaSenhaController, 'Nova senha',
                              Icons.lock_reset,
                              isPassword: true,
                              showPassword: _mostrarSenhaNova,
                              onToggle: () => setState(() =>
                                  _mostrarSenhaNova = !_mostrarSenhaNova)),
                          const SizedBox(height: 8),
                          _buildTextField(_confirmarSenhaController,
                              'Confirmar senha', Icons.lock_reset,
                              isPassword: true,
                              showPassword: _mostrarSenhaNova),
                          const SizedBox(height: 10),
                          _buildButton('Alterar Senha', Icons.check_circle,
                              _alterandoSenha, _alterarSenha, Colors.orange),
                        ])),
                const SizedBox(height: 10),

                // SEÇÃO SINC
                FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    child: _buildCard(
                        icon: Icons.sync,
                        title: 'Sincronização',
                        children: [
                          _buildButton('Sincronizar Agora', Icons.cloud_sync,
                              _sincronizando, _sincronizar, AppColors.info),
                        ])),
                const SizedBox(height: 10),

                // SOBRE
                FadeInUp(
                    duration: const Duration(milliseconds: 700),
                    child: _buildCard(
                        icon: Icons.info_outline,
                        title: 'Sobre',
                        children: [
                          _buildInfoRow('Versão', '1.0.0'),
                          _buildInfoRow('App', 'QI Controle'),
                          _buildInfoRow('Plataforma', 'Flutter + Supabase'),
                        ])),
                const SizedBox(height: 14),

                // SAIR
                FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout,
                            size: 18, color: Colors.white),
                        label: const Text('SAIR',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                      ),
                    )),
                const SizedBox(height: 16),
              ]),
            ),
    );
  }

  // ✅ NOVO: Widget de foto de perfil
  Widget _buildFotoPerfil() {
    return Center(
      child: GestureDetector(
        onTap: () async {
          final file = await _storageService.pickImage();
          if (file != null) {
            final url = await _storageService.uploadProfilePhoto(
              file,
              _supabase.auth.currentUser?.id ?? '',
            );
            if (url != null && mounted) {
              await _carregarPerfil();
              Toast.success(context, '✅ Foto atualizada!');
            } else {
              Toast.error(context, 'Erro ao enviar foto');
            }
          }
        },
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16), // ✅ QUADRADO
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 3,
                ),
                image: _perfil?['avatar_url'] != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(
                            '${_perfil!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}'),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _perfil?['avatar_url'] == null
                  ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8), // ✅ QUADRADO
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child:
                    const Icon(Icons.camera_alt, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context)))
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {String? hint,
      bool isPassword = false,
      bool showPassword = false,
      VoidCallback? onToggle,
      int? maxLength,
      TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !showPassword,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        labelStyle:
            TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                    color: AppColors.primary),
                onPressed: onToggle)
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border(context))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        filled: true,
        fillColor: AppColors.surface(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildEmailRow() {
    final email = _supabase.auth.currentUser?.email ?? 'Não disponível';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border(context)),
          color: AppColors.surface(context)),
      child: Row(children: [
        const Icon(Icons.email_outlined, color: Colors.grey, size: 18),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('E-mail',
              style: TextStyle(
                  fontSize: 10, color: AppColors.textSecondary(context))),
          Text(email,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textPrimary(context)))
        ])
      ]),
    );
  }

  Widget _buildButton(String label, IconData icon, bool loading,
      VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 16),
        label: Text(loading ? 'Aguarde...' : label,
            style: const TextStyle(fontSize: 12, color: Colors.white)),
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary(context))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(context))),
        ]));
  }
}
