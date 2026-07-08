// lib/screens/mobile/configuracoes_mobile.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/sync_service_improved.dart';
import '../../services/storage_service.dart';
import '../../services/update_service.dart';
import '../../database/db_helper.dart';
import '../../constants/app_colors.dart';
import '../../widgets/toast.dart';
import '../../services/logger_service.dart';

// ⬇️ IMPORT DA TELA DE DEBUG
import '../shared/debug_sync_screen.dart';

class ConfiguracoesMobileScreen extends StatefulWidget {
  const ConfiguracoesMobileScreen({super.key});

  @override
  State<ConfiguracoesMobileScreen> createState() =>
      _ConfiguracoesMobileScreenState();
}

class _ConfiguracoesMobileScreenState extends State<ConfiguracoesMobileScreen> {
  // Serviços
  final AuthService _auth = AuthService();
  final SyncService _syncService = SyncService();
  final StorageService _storageService = StorageService();
  final UpdateService _updateService = UpdateService();
  final DBHelper _dbHelper = DBHelper();
  final _supabase = Supabase.instance.client;

  // Controllers
  final _usernameController = TextEditingController();
  final _nomeController = TextEditingController();
  final _pinConfigController = TextEditingController();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  // Estados
  Map<String, dynamic>? _perfil;
  bool _carregando = true;
  bool _salvandoPerfil = false;
  bool _salvandoPin = false;
  bool _alterandoSenha = false;
  bool _sincronizando = false;
  bool _fotoCarregando = false;
  bool _verificandoUpdate = false;
  bool _mostrarPin = true;
  bool _mostrarSenhaAtual = true;
  bool _mostrarSenhaNova = true;

  // Força da senha
  double _forcaSenha = 0;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nomeController.dispose();
    _pinConfigController.dispose();
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _carregarPerfil() async {
    setState(() => _carregando = true);
    try {
      final perfilData = await _auth.getPerfil();
      if (!mounted) return;

      setState(() {
        _perfil = perfilData;
        if (_perfil != null) {
          _usernameController.text = _perfil!['username'] ?? '';
          _nomeController.text = _perfil!['nome'] ?? '';
          _pinConfigController.text = _perfil!['pin'] ?? '';
        }
        _carregando = false;
      });
    } catch (e) {
      LoggerService.error('Erro ao carregar perfil: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvarPerfil() async {
    final username = _usernameController.text.trim().toLowerCase();
    final nome = _nomeController.text.trim();

    if (username.isEmpty) {
      Toast.warning(context, 'Username é obrigatório');
      return;
    }
    if (nome.isEmpty) {
      Toast.warning(context, 'Nome é obrigatório');
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
        if (mounted) Toast.warning(context, 'Username já está em uso!');
        if (mounted) setState(() => _salvandoPerfil = false);
        return;
      }

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'nome': nome,
        'email': user.email,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Toast.success(context, '✅ Perfil atualizado!');
      await _carregarPerfil();
    } catch (e) {
      if (mounted) Toast.error(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvandoPerfil = false);
    }
  }

  Future<void> _salvarPin() async {
    final pin = _pinConfigController.text.trim();

    if (pin.isEmpty && _perfil?['pin'] != null) {
      final confirmar = await _mostrarDialogo(
        titulo: 'Remover PIN',
        mensagem: 'Tem certeza que deseja remover o PIN de acesso?',
        textoConfirmar: 'Remover',
        corConfirmar: Colors.red,
      );
      if (confirmar != true) return;
    }

    if (pin.isNotEmpty) {
      if (pin.length != 4 || int.tryParse(pin) == null) {
        Toast.warning(context, 'PIN deve ter 4 dígitos numéricos');
        return;
      }
    }

    setState(() => _salvandoPin = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('profiles')
          .update({'pin': pin.isEmpty ? null : pin}).eq('id', user.id);

      if (!mounted) return;
      Toast.success(context, pin.isEmpty ? '✅ PIN removido!' : '✅ PIN salvo!');
      await _carregarPerfil();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Toast.error(context, 'Erro ao salvar PIN');
    } finally {
      if (mounted) setState(() => _salvandoPin = false);
    }
  }

  Future<void> _alterarSenha() async {
    final senhaAtual = _senhaAtualController.text;
    final novaSenha = _novaSenhaController.text;
    final confirmarSenha = _confirmarSenhaController.text;

    if (senhaAtual.isEmpty) {
      Toast.warning(context, 'Digite a senha atual');
      return;
    }
    if (novaSenha.length < 6) {
      Toast.warning(context, 'Nova senha: mínimo 6 caracteres');
      return;
    }
    if (novaSenha != confirmarSenha) {
      Toast.warning(context, 'Senhas não conferem');
      return;
    }

    setState(() => _alterandoSenha = true);
    try {
      await _auth.updatePassword(novaSenha);
      if (!mounted) return;

      Toast.success(context, '✅ Senha alterada!');
      _senhaAtualController.clear();
      _novaSenhaController.clear();
      _confirmarSenhaController.clear();
      setState(() => _forcaSenha = 0);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) Toast.error(context, 'Erro ao alterar senha');
    } finally {
      if (mounted) setState(() => _alterandoSenha = false);
    }
  }

  void _calcularForcaSenha(String senha) {
    double forca = 0;
    if (senha.length >= 6) forca += 0.25;
    if (senha.length >= 8) forca += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(senha)) forca += 0.25;
    if (RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(senha)) forca += 0.25;
    setState(() => _forcaSenha = forca);
  }

  Color get _corForcaSenha {
    if (_forcaSenha < 0.25) return Colors.red;
    if (_forcaSenha < 0.5) return Colors.orange;
    if (_forcaSenha < 0.75) return Colors.yellow.shade700;
    return Colors.green;
  }

  String get _textoForcaSenha {
    if (_forcaSenha < 0.25) return 'Fraca';
    if (_forcaSenha < 0.5) return 'Regular';
    if (_forcaSenha < 0.75) return 'Boa';
    return 'Forte';
  }

  Future<void> _uploadFoto() async {
    if (_fotoCarregando) return;

    setState(() => _fotoCarregando = true);
    try {
      final file = await _storageService.pickImage();
      if (file == null) {
        setState(() => _fotoCarregando = false);
        return;
      }

      final confirmar = await _mostrarPreviewFoto(file);
      if (confirmar != true) {
        setState(() => _fotoCarregando = false);
        return;
      }

      final url = await _storageService.uploadProfilePhoto(
        file,
        _supabase.auth.currentUser?.id ?? '',
      );

      if (url != null && mounted) {
        await _carregarPerfil();
        Toast.success(context, '✅ Foto atualizada!');
      }
    } catch (e) {
      LoggerService.error('Erro ao fazer upload da foto: $e');
      if (mounted) Toast.error(context, 'Erro ao enviar foto');
    } finally {
      if (mounted) setState(() => _fotoCarregando = false);
    }
  }

  Future<bool?> _mostrarPreviewFoto(dynamic file) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nova foto',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
                image: DecorationImage(
                  image: FileImage(file),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Deseja usar esta foto?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _mostrarDialogo({
    required String titulo,
    required String mensagem,
    String textoCancelar = 'Cancelar',
    String textoConfirmar = 'Confirmar',
    Color corConfirmar = Colors.red,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title:
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(textoCancelar),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: corConfirmar,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(textoConfirmar,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ========== SINCRONIZAÇÃO MELHORADA ==========
  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        Toast.warning(context, 'Faça login primeiro');
        return;
      }

      Toast.info(context, '🔄 Sincronizando todos os dados...');

      final syncImproved = SyncServiceImproved();
      await syncImproved.syncAllData(force: true);

      final now = DateTime.now();
      await syncImproved.syncContasDoMes(now.year, now.month);

      await syncImproved.syncProventos();

      if (mounted) {
        Toast.success(context, '✅ Todos os dados sincronizados!');
      }
    } catch (e) {
      if (mounted) {
        Toast.error(context, 'Erro ao sincronizar: $e');
      }
      LoggerService.error('Erro na sincronização: $e');
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Future<void> _buscarAtualizacoes() async {
    setState(() => _verificandoUpdate = true);

    try {
      final update = await _updateService.checkForUpdate();

      if (mounted) {
        if (update != null) {
          _updateService.showUpdateDialog(context, update);
        } else {
          Toast.success(context, '✅ App está atualizado!');
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.error(context, 'Erro ao verificar atualizações: $e');
      }
    } finally {
      if (mounted) setState(() => _verificandoUpdate = false);
    }
  }

  void _abrirDebugSync() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DebugSyncScreen()),
    );
  }

  void _mostrarSheetPin() {
    _pinConfigController.text = _perfil?['pin'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '🔐 Configurar PIN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure um PIN de 4 dígitos para acesso rápido',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinConfigController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: _mostrarPin,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'PIN (4 dígitos)',
                labelStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarPin ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.primary,
                  ),
                  onPressed: () => setState(() => _mostrarPin = !_mostrarPin),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]!
                            : Colors.grey[400]!,
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _salvandoPin ? null : _salvarPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      minimumSize: const Size(0, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _salvandoPin
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Salvar PIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _mostrarSheetSenha() {
    _senhaAtualController.clear();
    _novaSenhaController.clear();
    _confirmarSenhaController.clear();
    _forcaSenha = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('🔒 Alterar Senha',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 8),
            Text('Sua senha deve ter no mínimo 6 caracteres',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                  fontSize: 13,
                )),
            const SizedBox(height: 20),
            TextField(
              controller: _senhaAtualController,
              obscureText: _mostrarSenhaAtual,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Senha atual',
                labelStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarSenhaAtual
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.primary,
                  ),
                  onPressed: () =>
                      setState(() => _mostrarSenhaAtual = !_mostrarSenhaAtual),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _novaSenhaController,
              obscureText: _mostrarSenhaNova,
              onChanged: _calcularForcaSenha,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Nova senha',
                labelStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarSenhaNova ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.primary,
                  ),
                  onPressed: () =>
                      setState(() => _mostrarSenhaNova = !_mostrarSenhaNova),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey[50],
              ),
            ),
            if (_novaSenhaController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _forcaSenha,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]
                          : Colors.grey[300],
                  color: _corForcaSenha,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Força: $_textoForcaSenha',
                  style: TextStyle(
                    fontSize: 11,
                    color: _corForcaSenha,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _confirmarSenhaController,
              obscureText: _mostrarSenhaNova,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Confirmar nova senha',
                labelStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                prefixIcon: const Icon(Icons.lock_reset),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]!
                            : Colors.grey[400]!,
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _alterandoSenha ? null : _alterarSenha,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(0, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _alterandoSenha
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Alterar Senha',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmarLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title:
            const Text('Sair', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Deseja realmente encerrar a sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _auth.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/profiles', (r) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Configurações',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _carregando
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Carregando...',
                      style:
                          TextStyle(color: AppColors.textSecondary(context))),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // ========== PERFIL ==========
                  _buildProfileHeader(),
                  const SizedBox(height: 16),

                  // ========== DADOS DA CONTA ==========
                  _buildSectionTitle('DADOS DA CONTA'),
                  _buildGroupContainer([
                    _buildModernField(
                      controller: _nomeController,
                      label: 'Nome Completo',
                      icon: Icons.person_outline,
                      color: Colors.blue,
                    ),
                    _buildModernField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.alternate_email,
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                        'Salvar Alterações', _salvandoPerfil, _salvarPerfil),
                  ]),
                  const SizedBox(height: 20),

                  // ========== SEGURANÇA ==========
                  _buildSectionTitle('SEGURANÇA'),
                  _buildGroupContainer([
                    _buildSettingsTile(
                      icon: Icons.lock_outline,
                      title: 'PIN de Acesso',
                      subtitle: _perfil?['pin'] != null
                          ? 'PIN configurado ●●●●'
                          : 'Configurar PIN de 4 dígitos',
                      color: Colors.orange,
                      onTap: _mostrarSheetPin,
                    ),
                    const Divider(height: 1, indent: 50),
                    _buildSettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Alterar Senha',
                      subtitle: 'Redefinir sua senha atual',
                      color: Colors.teal,
                      onTap: _mostrarSheetSenha,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ========== SISTEMA ==========
                  _buildSectionTitle('SISTEMA'),
                  _buildGroupContainer([
                    _buildSettingsTile(
                      icon: Icons.sync,
                      title: 'Sincronização',
                      subtitle: _sincronizando
                          ? 'Sincronizando...'
                          : 'Sincronizar todos os dados agora',
                      color: Colors.indigo,
                      trailing: _sincronizando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.indigo))
                          : const Icon(Icons.chevron_right,
                              color: Colors.grey, size: 18),
                      onTap: () {
                        if (!_sincronizando) _sincronizar();
                      },
                    ),
                    const Divider(height: 1, indent: 50),
                    _buildSettingsTile(
                      icon: Icons.system_update,
                      title: 'Buscar Atualizações',
                      subtitle: _verificandoUpdate
                          ? 'Verificando...'
                          : 'Verificar nova versão do app',
                      color: Colors.orange,
                      trailing: _verificandoUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.orange))
                          : const Icon(Icons.chevron_right,
                              color: Colors.orange, size: 18),
                      onTap: _verificandoUpdate ? null : _buscarAtualizacoes,
                    ),
                    const Divider(height: 1, indent: 50),
                    _buildSettingsTile(
                      icon: Icons.bug_report,
                      title: '🔍 Debug Sync',
                      subtitle: 'Verificar sincronização de dados',
                      color: Colors.red,
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.red, size: 18),
                      onTap: _abrirDebugSync,
                    ),
                    const Divider(height: 1, indent: 50),
                    _buildSettingsTile(
                      icon: Icons.info_outline,
                      title: 'Sobre',
                      subtitle: 'QI Controle v2.0 • Flutter + Supabase',
                      color: Colors.grey,
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // ========== BOTÃO SAIR ==========
                  FadeInUp(
                    child: TextButton.icon(
                      onPressed: _confirmarLogout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Sair da Conta',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ========== WIDGETS ==========

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploadFoto,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: _fotoCarregando
                      ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          ),
                        )
                      : ClipOval(
                          child: _perfil?['avatar_url'] != null
                              ? CachedNetworkImage(
                                  imageUrl:
                                      '${_perfil!['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                      color: Colors.white,
                                      child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                          color: Colors.white,
                                          child: const Icon(Icons.person,
                                              size: 50, color: Colors.grey)),
                                )
                              : Container(
                                  color: Colors.white,
                                  child: const Icon(Icons.person,
                                      size: 50, color: Colors.grey)),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _perfil?['nome'] ?? 'Usuário',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
          Text(
            '@${_perfil?['username'] ?? 'username'}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ),
          Text(
            _supabase.auth.currentUser?.email ?? '',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[500]
                  : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[500]
              : Colors.grey[600],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGroupContainer(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: children),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          border: UnderlineInputBorder(
            borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: color, width: 2),
          ),
          filled: false,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right,
              color: isDark ? Colors.grey[600] : Colors.grey[400], size: 18),
    );
  }

  Widget _buildActionButton(String label, bool loading, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
    );
  }
}
