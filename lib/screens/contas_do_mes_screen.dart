// lib/screens/contas_do_mes_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/conta_repository.dart';
import '../widgets/adicionar_conta_modal.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../services/logger_service.dart';
import '../widgets/toast.dart';
import '../services/theme_service.dart';

class ContasDoMesScreen extends StatefulWidget {
  const ContasDoMesScreen({super.key});

  @override
  State<ContasDoMesScreen> createState() => _ContasDoMesScreenState();
}

class _ContasDoMesScreenState extends State<ContasDoMesScreen> {
  final ContaRepository _repository = ContaRepository();

  List<Map<String, dynamic>> _pagamentos = [];
  Map<String, dynamic> _resumo = {};
  bool _isLoading = true;
  DateTime _mesSelecionado = DateTime.now();
  String _filtroStatus = 'Todas';

  final Map<dynamic, Map<String, dynamic>> _parcelasCache = {};

  final List<String> _meses = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez'
  ];

  final List<String> _statusOptions = [
    'Todas',
    'Pendentes',
    'Pagas',
    'Parceladas'
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
      _pagamentos = await _repository.getPagamentosDoMes(
          _mesSelecionado.year, _mesSelecionado.month);

      _resumo = await _repository.getResumoContasDoMes(
          _mesSelecionado.year, _mesSelecionado.month);

      await _carregarParcelasInfo();
    } catch (e) {
      LoggerService.error('Erro ao carregar: $e');
      if (mounted) {
        Toast.error(context, 'Erro ao carregar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarParcelasInfo() async {
    _parcelasCache.clear();
    for (var pagamento in _pagamentos) {
      final contaIdRaw = pagamento['conta_id'];
      final String contaId = contaIdRaw?.toString() ?? '';

      if (contaId.isEmpty) continue;

      final conta = await _repository.getContaByIdString(contaId);
      if (conta != null &&
          conta.parcelasTotal != null &&
          conta.parcelasTotal! > 1) {
        final parcelaAtual = _calcularParcelaAtual(pagamento, conta);
        final restantes = conta.parcelasTotal! - parcelaAtual;
        _parcelasCache[contaId] = {
          'atual': parcelaAtual,
          'total': conta.parcelasTotal,
          'restantes': restantes,
        };
      }
    }
  }

  int _calcularParcelaAtual(Map<String, dynamic> pagamento, dynamic conta) {
    try {
      final anoMes = pagamento['ano_mes'] as int? ?? 0;
      if (anoMes == 0) return 1;
      final ano = anoMes ~/ 100;
      final mes = anoMes % 100;
      final dataAtual = DateTime(ano, mes, 1);
      DateTime dataInicio;
      if (conta.dataInicio is DateTime) {
        dataInicio = conta.dataInicio as DateTime;
      } else if (conta.dataInicio is String) {
        dataInicio = DateTime.parse(conta.dataInicio as String);
      } else {
        return 1;
      }
      final mesesDiferenca = (dataAtual.year - dataInicio.year) * 12 +
          (dataAtual.month - dataInicio.month);
      int parcelaAtual = mesesDiferenca + 1;
      if (parcelaAtual < 1) parcelaAtual = 1;
      if (conta.parcelasTotal != null && parcelaAtual > conta.parcelasTotal!) {
        parcelaAtual = conta.parcelasTotal!;
      }
      return parcelaAtual;
    } catch (e) {
      return 1;
    }
  }

  void _navegarMes(int delta) {
    setState(() {
      _mesSelecionado =
          DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1);
      _parcelasCache.clear();
    });
    _carregarDados();
  }

  List<Map<String, dynamic>> get _contasFiltradas {
    if (_filtroStatus == 'Todas') return _pagamentos;
    if (_filtroStatus == 'Pendentes') {
      return _pagamentos.where((b) => b['status'] != 1).toList();
    }
    if (_filtroStatus == 'Pagas') {
      return _pagamentos.where((b) => b['status'] == 1).toList();
    }
    if (_filtroStatus == 'Parceladas') {
      return _pagamentos.where((b) {
        final contaId = b['conta_id']?.toString() ?? '';
        final parcelas = _parcelasCache[contaId];
        return parcelas != null && parcelas['total'] > 1;
      }).toList();
    }
    return _pagamentos;
  }

  Future<void> _pagarConta(Map<String, dynamic> pagamento) async {
    final pagamentoId = pagamento['id'];
    final contaNome = pagamento['conta_nome'];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: const Text('Pagar conta'),
        content: Text('Deseja pagar "$contaNome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('PAGAR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final result =
        await _repository.pagarContaComLancamentoString(pagamentoId.toString());

    // ✅ CORRIGIDO: result.when() -> if/else
    if (result.isSuccess) {
      _carregarDados();
      Toast.success(context, '✅ $contaNome paga!');
    } else {
      Toast.error(context, result.error);
    }
  }

  Future<void> _desfazerPagamento(Map<String, dynamic> pagamento) async {
    final pagamentoId = pagamento['id'];
    final contaNome = pagamento['conta_nome'];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: const Text('Desfazer pagamento'),
        content: Text('Deseja desfazer o pagamento de "$contaNome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('DESFAZER'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final result =
        await _repository.desfazerPagamentoString(pagamentoId.toString());

    // ✅ CORRIGIDO: result.when() -> if/else
    if (result.isSuccess) {
      _carregarDados();
      Toast.success(context, '↩️ Pagamento de $contaNome desfeito!');
    } else {
      Toast.error(context, result.error);
    }
  }

  void _editarConta(Map<String, dynamic> pagamento) async {
    try {
      final contaId = pagamento['conta_id']?.toString() ?? '';
      if (contaId.isEmpty) return;

      final conta = await _repository.getContaByIdString(contaId);
      if (conta == null) return;
      if (!mounted) return;

      final contaMap = conta.toJson();
      await AdicionarContaModal.show(
          context: context, conta: contaMap, onSalvo: () => _carregarDados());
    } catch (e) {
      LoggerService.error('Erro ao editar: $e');
      Toast.error(context, 'Erro ao editar: $e');
    }
  }

  void _excluirConta(Map<String, dynamic> pagamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: const Text('Excluir conta'),
        content: Text('Deseja excluir "${pagamento['conta_nome']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      final contaId = pagamento['conta_id']?.toString() ?? '';
      await _repository.deletarContaString(contaId);
      _carregarDados();
      Toast.success(context, '🗑️ ${pagamento['conta_nome']} excluida!');
    }
  }

  String _formatarDataVencimento(Map<String, dynamic> pagamento) {
    final anoMes = pagamento['ano_mes'] as int? ?? 0;
    if (anoMes == 0) return '--/--/----';
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    final dia = pagamento['dia_vencimento'] as int? ?? 1;
    return '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$ano';
  }

  bool _isAtrasado(Map<String, dynamic> pagamento) {
    final anoMes = pagamento['ano_mes'] as int? ?? 0;
    if (anoMes == 0) return false;
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    final dia = pagamento['dia_vencimento'] as int? ?? 1;
    final dataVencimento = DateTime(ano, mes, dia);
    return dataVencimento.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final totalPending = _pagamentos
        .where((b) => b['status'] != 1)
        .fold(0.0, (s, b) => s + (b['valor'] ?? 0));
    final totalPaid = _pagamentos
        .where((b) => b['status'] == 1)
        .fold(0.0, (s, b) => s + (b['valor'] ?? 0));
    final total = totalPending + totalPaid;
    final filteredBills = _contasFiltradas;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: null,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary(context),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Voltar',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textPrimary(context)),
            onPressed: _carregarDados,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 18),
                          onPressed: () => _navegarMes(-1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: AppColors.textPrimary(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_meses[_mesSelecionado.month - 1]} ${_mesSelecionado.year}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          onPressed: () => _navegarMes(1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: AppColors.textPrimary(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => AdicionarContaModal.show(
                      context: context,
                      onSalvo: () => _carregarDados(),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nova Conta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStatCard('A Pagar', totalPending, AppColors.error,
                          Icons.receipt),
                      const SizedBox(width: 12),
                      _buildStatCard('Pago', totalPaid, AppColors.success,
                          Icons.check_circle),
                      const SizedBox(width: 12),
                      _buildStatCard(
                          'Total', total, AppColors.primary, Icons.summarize),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border(context)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButton<String>(
                      value: _filtroStatus,
                      isExpanded: false,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down,
                          size: 18, color: AppColors.textSecondary(context)),
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textPrimary(context)),
                      dropdownColor: AppColors.surface(context),
                      items: _statusOptions.map((status) {
                        IconData? icon;
                        Color iconColor = AppColors.textSecondary(context);
                        if (status == 'Pendentes') {
                          icon = Icons.pending_actions;
                          iconColor = AppColors.warning;
                        } else if (status == 'Pagas') {
                          icon = Icons.check_circle;
                          iconColor = AppColors.success;
                        } else if (status == 'Parceladas') {
                          icon = Icons.repeat;
                          iconColor = AppColors.info;
                        }
                        return DropdownMenuItem(
                          value: status,
                          child: Row(
                            children: [
                              if (icon != null)
                                Icon(icon, size: 14, color: iconColor),
                              if (icon != null) const SizedBox(width: 6),
                              Text(status,
                                  style: TextStyle(
                                      color: AppColors.textPrimary(context))),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _filtroStatus = value!),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (filteredBills.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Icon(Icons.receipt,
                              size: 64, color: AppColors.muted(context)),
                          const SizedBox(height: 16),
                          Text('Nenhuma conta',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary(context))),
                          const SizedBox(height: 8),
                          Text('Clique em "Nova Conta" para adicionar',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint(context))),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredBills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final pagamento = filteredBills[index];
                        return _buildContaCard(pagamento);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(title,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context))),
            ]),
            const SizedBox(height: 4),
            Text(Formatador.moeda(value),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildContaCard(Map<String, dynamic> pagamento) {
    final estaPago = pagamento['status'] == 1;
    final atrasado = !estaPago && _isAtrasado(pagamento);
    final contaId = pagamento['conta_id']?.toString() ?? '';
    final parcelasInfo = _parcelasCache[contaId];
    final categoriaCor =
        AppColors.getCategoryColor(pagamento['categoria'] ?? 'Outros');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: estaPago
            ? AppColors.surface(context).withValues(alpha: 0.5)
            : AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: estaPago
              ? AppColors.border(context).withValues(alpha: 0.5)
              : (atrasado
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.border(context)),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: estaPago
                  ? AppColors.success.withValues(alpha: 0.1)
                  : (atrasado
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              estaPago
                  ? Icons.check_circle
                  : (atrasado ? Icons.warning_amber_rounded : Icons.receipt),
              color: estaPago
                  ? AppColors.success
                  : (atrasado ? AppColors.error : AppColors.primary),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(pagamento['conta_nome'] ?? 'Sem nome',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: estaPago
                              ? AppColors.textSecondary(context)
                              : AppColors.textPrimary(context))),
                  if (parcelasInfo != null && parcelasInfo['total'] > 1) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          '${parcelasInfo['atual']}/${parcelasInfo['total']}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: categoriaCor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(pagamento['categoria'] ?? 'Outros',
                        style: TextStyle(
                            fontSize: 9,
                            color: categoriaCor,
                            fontWeight: FontWeight.w500)),
                  ),
                  Text('Vence: ${_formatarDataVencimento(pagamento)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(context))),
                ]),
              ],
            ),
          ),
          Text(Formatador.moeda(pagamento['valor'] ?? 0),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: estaPago
                      ? AppColors.success
                      : (atrasado ? AppColors.error : AppColors.primary))),
          const SizedBox(width: 8),
          if (!estaPago)
            IconButton(
                onPressed: () => _pagarConta(pagamento),
                icon: const Icon(Icons.payment, size: 20),
                color: AppColors.textPrimary(context),
                tooltip: 'Pagar'),
          if (estaPago)
            IconButton(
                onPressed: () => _desfazerPagamento(pagamento),
                icon: const Icon(Icons.undo, size: 20),
                color: AppColors.textPrimary(context),
                tooltip: 'Desfazer'),
          IconButton(
              onPressed: () => _editarConta(pagamento),
              icon: const Icon(Icons.edit, size: 20),
              color: AppColors.textPrimary(context),
              tooltip: 'Editar'),
          IconButton(
              onPressed: () => _excluirConta(pagamento),
              icon: const Icon(Icons.delete, size: 20),
              color: AppColors.textPrimary(context),
              tooltip: 'Excluir'),
        ],
      ),
    );
  }
}
