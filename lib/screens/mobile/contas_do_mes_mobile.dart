// lib/screens/mobile/contas_do_mes_mobile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import '../../repositories/repositories.dart';
import '../../widgets/app_modals.dart';
import '../../constants/app_colors.dart';
import '../../models/conta_model.dart';
import '../../utils/formatters.dart';
import '../../services/logger_service.dart';
import '../../widgets/toast.dart';
import '../../services/sync_service_improved.dart';

class ContasDoMesMobileScreen extends StatefulWidget {
  const ContasDoMesMobileScreen({super.key});

  @override
  State<ContasDoMesMobileScreen> createState() =>
      _ContasDoMesMobileScreenState();
}

class _ContasDoMesMobileScreenState extends State<ContasDoMesMobileScreen> {
  final ContaRepository _repository = ContaRepository();
  final LancamentoRepository _lancamentoRepository = LancamentoRepository();
  final SyncServiceImproved _syncImproved = SyncServiceImproved();

  List<Map<String, dynamic>> _pagamentos = [];
  bool _isLoading = true;
  DateTime _mesSelecionado = DateTime.now();
  String _filtroStatus = 'Todas';
  final Map<String, Map<String, dynamic>> _parcelasCache = {};
  final Set<String> _contasPagasLocal = {};

  final List<String> _meses = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ'
  ];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // ============================================================
  // CARREGAR DADOS - ✅ REMOVIDA A SINC AUTOMÁTICA
  // ============================================================
  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dados = await _repository.getPagamentosDoMes(
          _mesSelecionado.year, _mesSelecionado.month);

      if (mounted) {
        setState(() {
          _pagamentos = dados;
          _contasPagasLocal
              .retainAll(_pagamentos.map((p) => p['id'].toString()));
        });
        await _carregarParcelasInfo();
      }

      // ✅ REMOVIDO: _syncImproved.syncContasDoMes - NÃO CHAMA MAIS AQUI
    } catch (e) {
      LoggerService.error('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarParcelasInfo() async {
    for (var p in _pagamentos) {
      final cid = p['conta_id']?.toString() ?? '';
      if (cid.isEmpty) continue;
      final c = await _repository.getContaByIdString(cid);
      if (c != null && (c.parcelasTotal ?? 0) > 1) {
        if (!mounted) return;
        setState(() {
          _parcelasCache[cid] = {
            'atual': _calcParcela(p, c),
            'total': c.parcelasTotal
          };
        });
      }
    }
  }

  int _calcParcela(Map<String, dynamic> p, dynamic c) {
    try {
      final am = p['ano_mes'] as int? ?? 0;
      if (am == 0) return 1;
      final dAtu = DateTime(am ~/ 100, am % 100, 1);
      final dIni = c.dataInicio is DateTime
          ? c.dataInicio
          : DateTime.parse(c.dataInicio.toString());
      final calc =
          ((dAtu.year - dIni.year) * 12 + (dAtu.month - dIni.month)) + 1;
      return calc.clamp(1, c.parcelasTotal ?? 1).toInt();
    } catch (e) {
      return 1;
    }
  }

  void _adicionarNovaConta() async {
    final resultado = await AppModals.mostrarModalConta(context: context);
    if (resultado != null) {
      debugPrint('📤 Dados enviados: $resultado');
      Toast.info(context, '💾 Adicionando conta...');
      try {
        final id = await _repository.adicionarConta(resultado);
        debugPrint('✅ ID retornado: $id');
        await Future.delayed(const Duration(milliseconds: 200));
        _carregarDados();
        Toast.success(context, '✅ Conta adicionada com sucesso!');
      } catch (e) {
        debugPrint('❌ ERRO: $e');
        LoggerService.error('Erro ao salvar conta: $e');
        Toast.error(context, 'Erro ao salvar conta localmente');
      }
    }
  }

  void _editar(Map<String, dynamic> b) async {
    Toast.info(context, '🔄 Abrindo editor...');

    final remoteId =
        b['remote_id']?.toString() ?? b['conta_id']?.toString() ?? '';
    final localId = b['conta_id']?.toString() ?? '';

    Conta? c;
    if (remoteId.isNotEmpty) {
      c = await _repository.getContaByIdString(remoteId);
    }
    if (c == null && localId.isNotEmpty) {
      c = await _repository.getContaByIdString(localId);
    }

    if (c == null) {
      Toast.error(context, 'Erro: Conta não encontrada');
      return;
    }

    AppModals.mostrarModalConta(
      context: context,
      conta: c.toJson(),
      onSalvo: () async {
        Toast.info(context, '💾 Salvando alterações...');
        await Future.delayed(const Duration(milliseconds: 200));
        _carregarDados();
        Toast.success(context, '✅ Conta salva com sucesso!');
      },
    );
  }

  void _excluir(Map<String, dynamic> b) async {
    final contaId = b['conta_id']?.toString() ?? '';
    final nome = b['conta_nome'] ?? 'esta conta';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Conta'),
        content:
            Text('Deseja excluir "$nome"?\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      Toast.info(context, '🔄 Excluindo...');
      try {
        await _repository.deletarContaString(contaId);
        await Future.delayed(const Duration(milliseconds: 300));
        Toast.success(context, '✅ Conta excluída com sucesso!');
        _carregarDados();
      } catch (e) {
        Toast.error(context, 'Erro ao excluir: $e');
        LoggerService.error('Erro ao excluir conta: $e');
      }
    }
  }

  Future<void> _pagar(Map<String, dynamic> b) async {
    final id = b['id'].toString();
    final res = await _repository.pagarContaComLancamentoString(id);
    if (res.isSuccess) {
      setState(() {
        _contasPagasLocal.add(id);
      });

      try {
        final lancamento = {
          'descricao': b['conta_nome'] ?? 'Conta paga',
          'valor': b['valor'] ?? 0.0,
          'tipo': 'gasto',
          'categoria': b['categoria'] ?? 'Outros',
          'data': DateTime.now().toIso8601String(),
        };
        await _lancamentoRepository.insertLancamento(lancamento);
        Toast.success(context, '✅ Conta paga e lançada com sucesso!');
      } catch (e) {
        LoggerService.error('Erro ao criar lançamento: $e');
        Toast.error(context, 'Conta paga, mas erro ao lançar: $e');
      }

      _carregarDados();
    } else {
      Toast.error(context, 'Erro ao pagar conta');
    }
  }

  void _navegar(int delta) {
    setState(() {
      _mesSelecionado =
          DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1);
      _parcelasCache.clear();
    });
    _carregarDados();
  }

  List<Map<String, dynamic>> _pagamentosFiltradas() {
    if (_filtroStatus == 'Pendentes') {
      return _pagamentos
          .where((b) =>
              (b['status'] ?? 0) != 1 &&
              !_contasPagasLocal.contains(b['id'].toString()))
          .toList();
    }
    if (_filtroStatus == 'Pagas') {
      return _pagamentos
          .where((b) =>
              (b['status'] ?? 0) == 1 ||
              _contasPagasLocal.contains(b['id'].toString()))
          .toList();
    }
    if (_filtroStatus == 'Parceladas') {
      return _pagamentos
          .where((b) =>
              (_parcelasCache[b['conta_id'].toString()]?['total'] ?? 0) > 1)
          .toList();
    }
    return _pagamentos;
  }

  @override
  Widget build(BuildContext context) {
    final pendingVal = _pagamentos
        .where((b) =>
            (b['status'] ?? 0) != 1 &&
            !_contasPagasLocal.contains(b['id'].toString()))
        .fold(0.0, (s, b) => s + (b['valor'] ?? 0.0));
    final paidVal = _pagamentos
        .where((b) =>
            (b['status'] ?? 0) == 1 ||
            _contasPagasLocal.contains(b['id'].toString()))
        .fold(0.0, (s, b) => s + (b['valor'] ?? 0.0));

    final filteredList = _pagamentosFiltradas();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text('Contas do Mês',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary(context))),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 22),
              onPressed: _adicionarNovaConta,
              tooltip: 'Adicionar conta',
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary(context), size: 22),
            onPressed: _carregarDados,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMesSelector(),
                _buildBalanceHeader(pendingVal, paidVal, isDark),
                _buildCompactFilter(isDark),
                Expanded(
                  child: filteredList.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _carregarDados,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              return FadeInLeft(
                                duration: const Duration(milliseconds: 300),
                                delay: Duration(milliseconds: index * 50),
                                child: _buildContaItem(filteredList[index]),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMesSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left,
                size: 28, color: AppColors.primary),
            onPressed: () {
              HapticFeedback.selectionClick();
              _navegar(-1);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text(
            '${_meses[_mesSelecionado.month - 1]} / ${_mesSelecionado.year}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right,
                size: 28, color: AppColors.primary),
            onPressed: () {
              HapticFeedback.selectionClick();
              _navegar(1);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader(double pending, double paid, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text("SAÍDAS DO MÊS",
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.grey)),
          const SizedBox(height: 4),
          Text(Formatador.moeda(pending + paid),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryColumn("A Pagar", pending, Colors.orangeAccent, isDark),
              Container(
                  width: 1,
                  height: 20,
                  color: isDark ? Colors.grey[700] : Colors.grey[300]),
              _summaryColumn("Pago", paid, Colors.greenAccent.shade700, isDark),
            ],
          )
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, double val, Color color, bool isDark) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 10)),
        const SizedBox(height: 2),
        Text(Formatador.moeda(val),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildCompactFilter(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['Todas', 'Pendentes', 'Pagas', 'Parceladas'].map((label) {
          bool sel = _filtroStatus == label;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => setState(() => _filtroStatus = label),
              child: Column(
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          color: sel
                              ? AppColors.primary
                              : (isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600]))),
                  if (sel)
                    FadeIn(
                        child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            height: 3,
                            width: 3,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history_toggle_off_rounded,
            size: 48, color: isDark ? Colors.grey[600] : Colors.grey[300]),
        const SizedBox(height: 8),
        Text("Sem histórico para este mês",
            style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[500],
                fontSize: 13)),
      ]),
    );
  }

  Widget _buildContaItem(Map<String, dynamic> conta) {
    final status = conta['status'] ?? 0;
    final id = conta['id'].toString();
    final isPaid = status == 1 || _contasPagasLocal.contains(id);
    final cid = conta['conta_id']?.toString() ?? '';
    final info = _parcelasCache[cid];
    final isParcelada = info != null && (info['total'] ?? 0) > 1;
    final nome = conta['conta_nome'] ?? 'Conta';
    final categoria = conta['categoria']?.toString().toUpperCase() ?? 'OUTROS';
    final valor = conta['valor'] ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isPaid
        ? Colors.green.withValues(alpha: 0.08)
        : (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final borderColor = isPaid
        ? Colors.green.withValues(alpha: 0.4)
        : (isDark ? Colors.grey[800]! : Colors.grey[200]!);
    final iconColor = isPaid ? Colors.green : AppColors.primary;
    final textColor = isPaid
        ? (isDark ? Colors.grey[400] : Colors.grey[600])
        : (isDark ? Colors.white : Colors.black87);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPaid
                    ? Colors.green.withValues(alpha: 0.15)
                    : iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid
                    ? Icons.check_circle_rounded
                    : (isParcelada
                        ? Icons.schedule_rounded
                        : Icons.calendar_today_rounded),
                color: iconColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        categoria,
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isParcelada) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${info['atual']}/${info['total']}',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPaid ? 'PAGA' : 'PENDENTE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatador.moeda(valor),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isPaid ? Colors.green : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (!isPaid)
                      SizedBox(
                        height: 24,
                        child: ElevatedButton(
                          onPressed: () => _pagar(conta),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'PAGAR',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _editar(conta),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit,
                            size: 14, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _excluir(conta),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.delete_outline,
                            size: 14, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
