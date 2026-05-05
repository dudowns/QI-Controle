// lib/screens/profiles_screen.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../constants/app_colors.dart';
import '../widgets/toast.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});
  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen>
    with TickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final SyncService _syncService = SyncService();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _perfis = [];
  bool _carregando = true;
  int? _perfilSelecionado;
  int? _perfilHover;
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _mostrarPin = false;
  String? _ultimoPerfilId;
  bool _fazendoLogin = false;

  late AnimationController _pinAnimationController;
  late Animation<double> _pinAnimation;

  final List<Color> _coresAvatares = [
    const Color(0xFF1B5F8C),
    const Color(0xFFE91E63),
    const Color(0xFF2E86AB),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
  ];

  final List<IconData> _iconesAvatares = [
    Icons.face,
    Icons.face_2,
    Icons.face_3,
    Icons.face_4,
    Icons.face_5,
  ];

  @override
  void initState() {
    super.initState();
    _pinAnimationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _pinAnimation = CurvedAnimation(
        parent: _pinAnimationController, curve: Curves.easeOutBack);
    _carregarPerfis();
    _carregarUltimoPerfil();
  }

  @override
  void dispose() {
    _pinAnimationController.dispose();
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _carregarUltimoPerfil() async {
    try {
      final saved = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_last', true)
          .maybeSingle();
      if (saved != null) _ultimoPerfilId = saved['id']?.toString();
    } catch (e) {}
  }

  Future<void> _salvarUltimoPerfil(String id) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_last': false}).neq('id', '00000000');
      await _supabase.from('profiles').update({'is_last': true}).eq('id', id);
    } catch (e) {}
  }

  Future<void> _carregarPerfis() async {
    setState(() => _carregando = true);
    try {
      final response =
          await _supabase.from('profiles').select('*').order('created_at');
      _perfis = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      final perfil = await _auth.getPerfil();
      if (perfil != null) _perfis = [perfil];
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _abrirPinModal(Map<String, dynamic> perfil) {
    if (_perfilSelecionado != null) return;
    setState(() {
      _perfilSelecionado = _perfis.indexOf(perfil);
      _pinController.clear();
      _mostrarPin = true;
    });
    _pinAnimationController.forward();
    Future.delayed(
        const Duration(milliseconds: 100), () => _focusNode.requestFocus());
  }

  void _fecharPinModal() {
    _pinAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _mostrarPin = false;
          _perfilSelecionado = null;
          _pinController.clear();
          _fazendoLogin = false;
        });
      }
    });
  }

  Future<void> _verificarPin(Map<String, dynamic> perfil) async {
    final valor = _pinController.text.trim();
    if (valor.isEmpty) {
      Toast.warning(context, 'Digite seu PIN');
      return;
    }

    final temPin = perfil['pin'] != null && perfil['pin'].toString().isNotEmpty;

    if (!temPin) {
      _fecharPinModal();
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (valor == perfil['pin'].toString()) {
      setState(() => _fazendoLogin = true);

      final sessaoAtual = _supabase.auth.currentSession;

      if (sessaoAtual != null) {
        await _salvarUltimoPerfil(perfil['id']?.toString() ?? '');
        await _syncService.syncNow();
        if (mounted) Navigator.pushReplacementNamed(context, '/main');
      } else {
        _fecharPinModal();
        Navigator.pushNamed(context, '/login');
      }
    } else {
      Toast.error(context, 'PIN incorreto!');
      _pinController.clear();
      _focusNode.requestFocus();
      setState(() => _fazendoLogin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
              Color(0xFF0D1B2A),
              Color(0xFF133B5C),
              Color(0xFF0D1B2A)
            ])),
        child: SafeArea(
          child: Stack(children: [
            _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : Column(children: [
                    const SizedBox(height: 50),
                    FadeInDown(
                        duration: const Duration(milliseconds: 800),
                        child: const Text('Quem vai usar o app?',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    const SizedBox(height: 8),
                    FadeInDown(
                        duration: const Duration(milliseconds: 1000),
                        child: Text('Selecione seu perfil',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.6)))),
                    const SizedBox(height: 40),
                    Expanded(
                        child: Center(
                            child: Wrap(
                                spacing: 35,
                                runSpacing: 30,
                                alignment: WrapAlignment.center,
                                children: [
                          ..._perfis
                              .asMap()
                              .entries
                              .map((e) => _buildPerfilCard(e.key)),
                          _buildAdicionarCard()
                        ]))),
                    const SizedBox(height: 20),
                    FadeInUp(
                        duration: const Duration(milliseconds: 1200),
                        child: TextButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/login'),
                            icon: const Icon(Icons.login,
                                color: Colors.white70, size: 16),
                            label: const Text('Outro login',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)))),
                    const SizedBox(height: 30),
                  ]),
            if (_mostrarPin && _perfilSelecionado != null) _buildPinOverlay(),
          ]),
        ),
      ),
    );
  }

  Widget _buildPinOverlay() {
    final perfil = _perfis[_perfilSelecionado!];
    final temPin = perfil['pin'] != null && perfil['pin'].toString().isNotEmpty;
    return GestureDetector(
      onTap: _fecharPinModal,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ScaleTransition(
              scale: _pinAnimation,
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: perfil['avatar_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(
                                    '${perfil['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}'),
                                fit: BoxFit.cover,
                              )
                            : null,
                        gradient: perfil['avatar_url'] != null
                            ? null
                            : LinearGradient(colors: [
                                _coresAvatares[_perfilSelecionado! %
                                    _coresAvatares.length],
                                _coresAvatares[_perfilSelecionado! %
                                        _coresAvatares.length]
                                    .withValues(alpha: 0.7)
                              ]),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: perfil['avatar_url'] != null
                          ? const SizedBox()
                          : Icon(
                              _iconesAvatares[
                                  _perfilSelecionado! % _iconesAvatares.length],
                              size: 28,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Olá, ${perfil['nome'] ?? 'Usuário'}!',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      temPin
                          ? 'Digite seu PIN'
                          : 'Clique em entrar para fazer login',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 14),
                    if (temPin)
                      TextField(
                        controller: _pinController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        enabled: !_fazendoLogin,
                        style: const TextStyle(
                          fontSize: 26,
                          letterSpacing: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: '0000',
                          hintStyle:
                              TextStyle(color: Colors.grey[400], fontSize: 20),
                          counterText: '',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: _fazendoLogin
                            ? null
                            : (value) => _verificarPin(perfil),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed:
                            _fazendoLogin ? null : () => _verificarPin(perfil),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _fazendoLogin
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('ENTRAR',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _fazendoLogin ? null : _fecharPinModal,
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
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

  Widget _buildPerfilCard(int index) {
    final perfil = _perfis[index];
    final cor = _coresAvatares[index % _coresAvatares.length];
    final icone = _iconesAvatares[index % _iconesAvatares.length];
    final nome = perfil['nome']?.toString() ??
        perfil['username']?.toString() ??
        'Usuário';
    final temPin = perfil['pin'] != null && perfil['pin'].toString().isNotEmpty;
    final isUltimo = perfil['id']?.toString() == _ultimoPerfilId;
    final isHover = _perfilHover == index;
    return MouseRegion(
      onEnter: (_) => setState(() => _perfilHover = index),
      onExit: (_) => setState(() => _perfilHover = null),
      child: FadeInUp(
          duration: Duration(milliseconds: 400 + (index * 100)),
          child: GestureDetector(
            onTap: () => _abrirPinModal(perfil),
            onLongPress: () => _mostrarOpcoesPerfil(perfil),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: isHover
                    ? (Matrix4.identity()..scale(1.05))
                    : Matrix4.identity(),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(alignment: Alignment.bottomRight, children: [
                    Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: cor.withValues(alpha: 0.3),
                            image: perfil['avatar_url'] != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                        '${perfil['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}'),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            gradient: perfil['avatar_url'] != null
                                ? null
                                : LinearGradient(
                                    colors: [cor, cor.withValues(alpha: 0.7)]),
                            boxShadow: [
                              BoxShadow(
                                  color: cor.withValues(
                                      alpha: isHover ? 0.7 : 0.4),
                                  blurRadius: isHover ? 20 : 12)
                            ],
                            border: Border.all(
                                color: isUltimo || isHover
                                    ? Colors.amber
                                    : Colors.white.withValues(alpha: 0.3),
                                width: (isUltimo || isHover) ? 3 : 2)),
                        child: perfil['avatar_url'] != null
                            ? const SizedBox()
                            : Icon(icone, size: 55, color: Colors.white)),
                    if (isUltimo)
                      Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                              color: Colors.amber, shape: BoxShape.circle),
                          child: const Icon(Icons.star,
                              size: 14, color: Colors.white)),
                  ]),
                  const SizedBox(height: 6),
                  Text(nome,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isUltimo ? Colors.amber : Colors.white)),
                  const SizedBox(height: 3),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: (isUltimo ? Colors.amber : Colors.white)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(temPin ? Icons.lock : Icons.lock_open,
                            size: 9,
                            color: isUltimo ? Colors.amber : Colors.white70),
                        const SizedBox(width: 3),
                        Text(temPin ? 'PIN' : 'Senha',
                            style: TextStyle(
                                fontSize: 9,
                                color:
                                    isUltimo ? Colors.amber : Colors.white70)),
                      ])),
                ])),
          )),
    );
  }

  Widget _buildAdicionarCard() => FadeInUp(
      duration: const Duration(milliseconds: 800),
      child: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/register'),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 2)),
                child: const Icon(Icons.person_add,
                    size: 50, color: Colors.white60)),
            const SizedBox(height: 6),
            const Text('Adicionar',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white60))
          ])));

  void _mostrarOpcoesPerfil(Map<String, dynamic> perfil) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.primary),
                  title: const Text('Editar Perfil'),
                  onTap: () {
                    Navigator.pop(context);
                    _editarPerfil(perfil);
                  }),
              ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remover Perfil',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _removerPerfil(perfil);
                  }),
              const SizedBox(height: 20),
            ])));
  }

  Future<void> _editarPerfil(Map<String, dynamic> perfil) async {
    final nomeController =
        TextEditingController(text: perfil['nome']?.toString() ?? '');
    final pinController = TextEditingController();
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                backgroundColor: AppColors.cardBackground(context),
                title: const Text('Editar Perfil'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: nomeController,
                      decoration: InputDecoration(
                          labelText: 'Nome',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.surface(context))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                          labelText: 'Novo PIN (4 dígitos)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.surface(context)))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: const Text('Salvar'))
                ]));
    if (result == true && mounted) {
      try {
        final updates = <String, dynamic>{'nome': nomeController.text.trim()};
        if (pinController.text.length == 4) updates['pin'] = pinController.text;
        await _supabase
            .from('profiles')
            .update(updates)
            .eq('id', perfil['id']?.toString() ?? '');
        await _carregarPerfis();
        Toast.success(context, '✅ Perfil atualizado!');
      } catch (e) {
        Toast.error(context, 'Erro: $e');
      }
    }
  }

  Future<void> _removerPerfil(Map<String, dynamic> perfil) async {
    final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Remover Perfil'),
                content:
                    Text('Deseja remover ${perfil['nome'] ?? 'este perfil'}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Remover',
                          style: TextStyle(color: Colors.white)))
                ]));
    if (confirmar == true && mounted) {
      try {
        await _supabase
            .from('profiles')
            .delete()
            .eq('id', perfil['id']?.toString() ?? '');
        await _carregarPerfis();
        Toast.success(context, '✅ Perfil removido!');
      } catch (e) {
        Toast.error(context, 'Erro: $e');
      }
    }
  }
}
