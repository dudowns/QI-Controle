// lib/screens/contas_do_mes_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/repositories.dart';
import '../widgets/adicionar_conta_modal.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../services/logger_service.dart';
import '../widgets/toast.dart';

class ContasDoMesScreen extends StatefulWidget {
  const ContasDoMesScreen({super.key});
  @override
  State<ContasDoMesScreen> createState() => _ContasDoMesScreenState();
}

class _ContasDoMesScreenState extends State<ContasDoMesScreen> {
  final ContaRepository _repository = ContaRepository();
  List<Map<String, dynamic>> _pagamentos = [];
  bool _isLoading = true;
  DateTime _mesSelecionado = DateTime.now();
  String _filtroStatus = 'Todas';
  final Map<String, Map<String, dynamic>> _parcelasCache = {};
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

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      _pagamentos = await _repository.getPagamentosDoMes(
          _mesSelecionado.year, _mesSelecionado.month);
      await _carregarParcelasInfo();
    } catch (e) {
      LoggerService.error('Erro ao carregar: $e');
      if (mounted) Toast.error(context, 'Erro ao carregar contas');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarParcelasInfo() async {
    _parcelasCache.clear();
    for (var pagamento in _pagamentos) {
      final contaId = pagamento['conta_id']?.toString() ?? '';
      if (contaId.isEmpty) continue;
      final conta = await _repository.getContaByIdString(contaId);
      if (conta != null &&
          conta.parcelasTotal != null &&
          conta.parcelasTotal! > 1) {
        final parcelaAtual = _calcularParcelaAtual(pagamento, conta);
        _parcelasCache[contaId] = {
          'atual': parcelaAtual,
          'total': conta.parcelasTotal,
          'restantes': conta.parcelasTotal! - parcelaAtual
        };
      }
    }
  }

  int _calcularParcelaAtual(Map<String, dynamic> pagamento, dynamic conta) {
    try {
      if (conta == null) return 1;
      final anoMes = pagamento['ano_mes'] as int? ?? 0;
      if (anoMes == 0) return 1;
      final dataAtual = DateTime(anoMes ~/ 100, anoMes % 100, 1);
      DateTime dataInicio;
      if (conta.dataInicio is DateTime) {
        dataInicio = conta.dataInicio as DateTime;
      } else if (conta.dataInicio is String) {
        dataInicio = DateTime.parse(conta.dataInicio as String);
      } else {
        return 1;
      }
      int parcelaAtual = ((dataAtual.year - dataInicio.year) * 12 +
              (dataAtual.month - dataInicio.month)) +
          1;
      if (parcelaAtual < 1) parcelaAtual = 1;
      final total = conta.parcelasTotal as int?;
      if (total != null && parcelaAtual > total) parcelaAtual = total;
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
    if (_filtroStatus == 'Pendentes')
      return _pagamentos.where((b) => b['status'] != 1).toList();
    if (_filtroStatus == 'Pagas')
      return _pagamentos.where((b) => b['status'] == 1).toList();
    if (_filtroStatus == 'Parceladas') {
      return _pagamentos.where((b) {
        final cid = b['conta_id']?.toString() ?? '';
        final p = _parcelasCache[cid];
        return p != null &&
            (p['total'] as int?) != null &&
            (p['total'] as int) > 1;
      }).toList();
    }
    return _pagamentos;
  }

  Future<void> _pagarConta(Map<String, dynamic> pagamento) async {
    final id = pagamento['id'].toString();
    final result = await _repository.pagarContaComLancamentoString(id);
    if (!mounted) return;
    if (result.isSuccess) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _carregarDados();
      if (mounted) Toast.success(context, 'Conta paga!');
    } else {
      Toast.error(context, result.error);
    }
  }

  void _editarConta(Map<String, dynamic> pagamento) async {
    final contaId = pagamento['conta_id']?.toString() ?? '';
    if (contaId.isEmpty) return;
    final conta = await _repository.getContaByIdString(contaId);
    if (conta == null) return;
    await AdicionarContaModal.show(
        context: context, conta: conta.toJson(), onSalvo: _carregarDados);
  }

  void _excluirConta(Map<String, dynamic> pagamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta'),
        content: Text('Deseja excluir "${pagamento['conta_nome']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar == true) {
      await _repository
          .deletarContaString(pagamento['conta_id']?.toString() ?? '');
      _carregarDados();
      if (mounted) Toast.success(context, 'Conta excluida!');
    }
  }

  String _formatarDataVencimento(Map<String, dynamic> pagamento) {
    final anoMes = pagamento['ano_mes'] as int? ?? 0;
    if (anoMes == 0) return '--/--/----';
    final dia =
        (pagamento['dia_vencimento'] as int? ?? 1).toString().padLeft(2, '0');
    final mes = (anoMes % 100).toString().padLeft(2, '0');
    final ano = anoMes ~/ 100;
    return '$dia/$mes/$ano';
  }

  bool _isAtrasado(Map<String, dynamic> pagamento) {
    final anoMes = pagamento['ano_mes'] as int? ?? 0;
    if (anoMes == 0) return false;
    final dia = pagamento['dia_vencimento'] as int? ?? 1;
    return DateTime(anoMes ~/ 100, anoMes % 100, dia).isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final totalPending = _pagamentos
        .where((b) => b['status'] != 1)
        .fold(0.0, (s, b) => s + (b['valor'] ?? 0));
    final totalPaid = _pagamentos
        .where((b) => b['status'] == 1)
        .fold(0.0, (s, b) => s + (b['valor'] ?? 0));
    final filteredBills = _contasFiltradas;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
          title: null,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textPrimary(context),
          centerTitle: false,
          actions: [
            IconButton(
                icon:
                    Icon(Icons.refresh, color: AppColors.textPrimary(context)),
                onPressed: _carregarDados,
                tooltip: 'Atualizar'),
            const SizedBox(width: 8)
          ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildStatsRow(totalPending, totalPaid),
              const SizedBox(height: 12),
              _buildBillsList(filteredBills)
            ]),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left, size: 16),
                    onPressed: () => _navegarMes(-1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.textPrimary(context)),
                const SizedBox(width: 4),
                Text(
                    '${_meses[_mesSelecionado.month - 1]} ${_mesSelecionado.year}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(context))),
                const SizedBox(width: 4),
                IconButton(
                    icon: const Icon(Icons.chevron_right, size: 16),
                    onPressed: () => _navegarMes(1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.textPrimary(context))
              ])),
          const SizedBox(height: 6),
          ElevatedButton.icon(
              onPressed: () => AdicionarContaModal.show(
                  context: context, onSalvo: _carregarDados),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Nova Conta', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
          const SizedBox(height: 6),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: 30,
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border(context)),
                  borderRadius: BorderRadius.circular(20)),
              child: DropdownButton<String>(
                  value: _filtroStatus,
                  isExpanded: false,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down,
                      size: 16, color: AppColors.textSecondary(context)),
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textPrimary(context)),
                  dropdownColor: AppColors.surface(context),
                  items: ['Todas', 'Pendentes', 'Pagas', 'Parceladas']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _filtroStatus = v!))),
        ]),
      ]),
    );
  }

  Widget _buildStatsRow(double totalPending, double totalPaid) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _buildStatCard(
              'A Pagar', totalPending, AppColors.error, Icons.receipt),
          const SizedBox(width: 12),
          _buildStatCard(
              'Pago', totalPaid, AppColors.success, Icons.check_circle),
          const SizedBox(width: 12),
          _buildStatCard('Total', totalPending + totalPaid, AppColors.primary,
              Icons.summarize)
        ]));
  }

  Widget _buildBillsList(List<Map<String, dynamic>> bills) {
    if (bills.isEmpty) {
      return Expanded(
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
            Icon(Icons.receipt, size: 64, color: AppColors.muted(context)),
            const SizedBox(height: 16),
            Text('Nenhuma conta',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context))),
            const SizedBox(height: 8),
            Text('Clique em "Nova Conta" para adicionar',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textHint(context)))
          ])));
    }
    return Expanded(
        child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: bills.length,
            itemBuilder: (context, index) => _buildBillCard(bills[index])));
  }

  Widget _buildStatCard(
      String title, double value, Color color, IconData icon) {
    return Expanded(
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
                color: AppColors.cardBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(context))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(title,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary(context)))
              ]),
              const SizedBox(height: 4),
              Text(Formatador.moeda(value),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color))
            ])));
  }

  Widget _buildBillCard(Map<String, dynamic> pagamento) {
    final estaPago = pagamento['status'] == 1;
    final atrasado = !estaPago && _isAtrasado(pagamento);
    final parcelasInfo =
        _parcelasCache[pagamento['conta_id']?.toString() ?? ''];
    final categoriaCor =
        AppColors.getCategoryColor(pagamento['categoria'] ?? 'Outros');

    final List<Widget> rowChildren = [
      Text(pagamento['conta_nome'] ?? 'Sem nome',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: estaPago
                  ? AppColors.textSecondary(context)
                  : AppColors.textPrimary(context),
              decoration: estaPago ? TextDecoration.lineThrough : null)),
    ];
    if (parcelasInfo != null && parcelasInfo['total'] > 1) {
      rowChildren.add(const SizedBox(width: 8));
      rowChildren.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text('${parcelasInfo['atual']}/${parcelasInfo['total']}',
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500))));
    }

    final List<Widget> wrapChildren = [
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: categoriaCor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Text(pagamento['categoria'] ?? 'Outros',
              style: TextStyle(
                  fontSize: 9,
                  color: categoriaCor,
                  fontWeight: FontWeight.w500))),
      Text('Vence: ${_formatarDataVencimento(pagamento)}',
          style:
              TextStyle(fontSize: 10, color: AppColors.textSecondary(context))),
    ];
    if (atrasado) {
      wrapChildren.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
          child: const Text('Atrasada',
              style: TextStyle(
                  fontSize: 9,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500))));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: estaPago
                  ? AppColors.border(context).withValues(alpha: 0.5)
                  : (atrasado
                      ? AppColors.error.withValues(alpha: 0.3)
                      : AppColors.border(context)),
              width: 0.5)),
      elevation: 0,
      color: estaPago
          ? AppColors.cardBackground(context).withValues(alpha: 0.6)
          : AppColors.cardBackground(context),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: estaPago
                        ? AppColors.success.withValues(alpha: 0.1)
                        : (atrasado
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    estaPago
                        ? Icons.check_circle
                        : (atrasado
                            ? Icons.warning_amber_rounded
                            : Icons.receipt),
                    color: estaPago
                        ? AppColors.success
                        : (atrasado ? AppColors.error : AppColors.primary),
                    size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: rowChildren),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, children: wrapChildren)
                ])),
            Text(Formatador.moeda(pagamento['valor'] ?? 0),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: estaPago
                        ? AppColors.success
                        : (atrasado ? AppColors.error : AppColors.primary))),
            const SizedBox(width: 4),
            if (!estaPago)
              IconButton(
                  icon: const Icon(Icons.check, size: 20),
                  color: Colors.green,
                  onPressed: () => _pagarConta(pagamento),
                  tooltip: 'Pagar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: AppColors.textSecondary(context),
                onPressed: () => _editarConta(pagamento),
                tooltip: 'Editar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
            IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.textSecondary(context),
                onPressed: () => _excluirConta(pagamento),
                tooltip: 'Excluir',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ])),
    );
  }
}
