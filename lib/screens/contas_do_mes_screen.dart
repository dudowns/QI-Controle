// lib/screens/contas_do_mes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import '../repositories/repositories.dart';
import '../widgets/app_modals.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../services/logger_service.dart';
import '../widgets/toast.dart';
import '../main.dart';

class ContasDoMesScreen extends StatefulWidget {
  const ContasDoMesScreen({super.key});

  @override
  State<ContasDoMesScreen> createState() => _ContasDoMesScreenState();
}

class _ContasDoMesScreenState extends State<ContasDoMesScreen> {
  final ContaRepository _repository = ContaRepository();
  final LancamentoRepository _lancamentoRepository = LancamentoRepository();
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
              // 🔥 CORRIGIDO: Agora chama a função unificada
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
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildMesSelector()),
                SliverToBoxAdapter(
                    child: _buildBalanceHeader(pendingVal, paidVal)),
                SliverToBoxAdapter(child: _buildCompactFilter()),
                filteredList.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : SliverToBoxAdapter(child: _buildContasCard(filteredList)),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
    );
  }

  Widget _buildContasCard(List<Map<String, dynamic>> contas) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.border(context).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEEE)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Spacer(),
                  Text(
                    '${contas.length} conta(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            ...contas.map((conta) => _buildContaItem(conta)).toList(),
          ],
        ),
      ),
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

    final backgroundColor = isPaid
        ? Colors.green.withValues(alpha: 0.08)
        : AppColors.cardBackground(context);
    final borderColor = isPaid
        ? Colors.green.withValues(alpha: 0.4)
        : AppColors.border(context).withValues(alpha: 0.3);
    final iconColor = isPaid ? Colors.green : AppColors.primary;
    final textColor = isPaid
        ? AppColors.textSecondary(context)
        : AppColors.textPrimary(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: AppColors.border(context).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 40,
              height: 40,
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
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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
                          fontSize: 10,
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isParcelada) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${info['atual']}/${info['total']}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPaid ? 'PAGA' : 'PENDENTE',
                          style: TextStyle(
                            fontSize: 9,
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
                    fontSize: 14,
                    color: isPaid ? Colors.green : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      child: isPaid
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_rounded,
                                      color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'PAGO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SizedBox(
                              height: 28,
                              child: ElevatedButton(
                                onPressed: () => _pagar(conta),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'PAGAR',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _editar(conta),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _excluir(conta),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline,
                            size: 16, color: Colors.red),
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

  // 🔥 FUNÇÃO DE ADIÇÃO DEFINITIVA (CORRIGIDA E UNIFICADA)
  void _adicionarNovaConta() async {
    final resultado = await AppModals.mostrarModalConta(context: context);
    if (resultado != null) {
      Toast.info(context, '💾 Adicionando conta...');
      try {
        await _repository.adicionarConta(resultado);

        // 🔥 CORREÇÃO DEFINITIVA:
        // Nós não precisamos mais chamar o limparCacheCompleto manualmente.
        // O seu repositório já está configurado para limpar o cache
        // automaticamente quando você usa o adicionarConta.

        // Aguarda um instante e recarrega a tela
        await Future.delayed(const Duration(milliseconds: 200));
        _carregarDados();
        Toast.success(context, '✅ Conta adicionada com sucesso!');
      } catch (e) {
        LoggerService.error('Erro ao salvar conta: $e');
        Toast.error(context, 'Erro ao salvar conta localmente');
      }
    }
  }

  // 🔥 FUNÇÃO EDITAR COM RECARREGAMENTO FORÇADO
  void _editar(Map<String, dynamic> b) async {
    Toast.info(context, '🔄 Abrindo editor...');
    final c = await _repository.getContaByIdString(b['conta_id'].toString());
    if (c == null) {
      Toast.error(context, 'Erro: Conta não encontrada');
      return;
    }

    AppModals.mostrarModalConta(
      context: context,
      conta: c.toJson(),
      onSalvo: () async {
        Toast.info(context, '💾 Salvando alterações...');
        // 🔥 Aguarda um instante e recarrega a tela
        await Future.delayed(const Duration(milliseconds: 200));
        _carregarDados();
        Toast.success(context, '✅ Conta salva com sucesso!');
      },
    );
  }

  void _excluir(Map<String, dynamic> b) async {
    final confirmado = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Excluir'),
        content: Text('Deseja excluir "${b['conta_nome'] ?? 'esta conta'}"?'),
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
      setState(() {
        _pagamentos
            .removeWhere((item) => item['id'].toString() == b['id'].toString());
      });

      Toast.success(context, '🔄 Excluindo...');

      await _repository.deletarContaString(b['conta_id'].toString());

      await Future.delayed(const Duration(seconds: 2));

      Toast.success(context, '✅ Conta excluída com sucesso!');
      _carregarDados();
    }
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
              fontSize: 16,
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

  Widget _buildBalanceHeader(double pending, double paid) {
    return FadeIn(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10))
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
            const SizedBox(height: 8),
            Text(Formatador.moeda(pending + paid),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryColumn("A Pagar", pending, Colors.orangeAccent),
                Container(
                    width: 1, height: 24, color: AppColors.border(context)),
                _summaryColumn("Pago", paid, Colors.greenAccent.shade700),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _summaryColumn(String label, double val, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 10)),
        const SizedBox(height: 2),
        Text(Formatador.moeda(val),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildCompactFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              : AppColors.textSecondary(context))),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history_toggle_off_rounded,
            size: 48, color: AppColors.border(context)),
        const SizedBox(height: 8),
        const Text("Sem histórico para este mês",
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]),
    );
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

  bool _atrasado(Map<String, dynamic> b) {
    final am = b['ano_mes'] as int? ?? 0;
    return DateTime(am ~/ 100, am % 100, b['dia_vencimento'] as int? ?? 1)
        .isBefore(DateTime.now());
  }
}
