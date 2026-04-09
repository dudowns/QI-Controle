// lib/screens/contas_do_mes_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/conta_repository.dart';
import '../widgets/adicionar_conta_modal.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../services/logger_service.dart';

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

  final Map<int, Map<String, dynamic>> _parcelasCache = {};

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      LoggerService.info(
          '📊 Carregando contas para ${_mesSelecionado.year}/${_mesSelecionado.month}');

      _pagamentos = await _repository.getPagamentosDoMes(
          _mesSelecionado.year, _mesSelecionado.month);

      LoggerService.info('📊 Pagamentos encontrados: ${_pagamentos.length}');

      _resumo = await _repository.getResumoContasDoMes(
          _mesSelecionado.year, _mesSelecionado.month);
      await _carregarParcelasInfo();
    } catch (e) {
      LoggerService.error('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarParcelasInfo() async {
    _parcelasCache.clear();
    for (var pagamento in _pagamentos) {
      final contaId = pagamento['conta_id'] as int;
      final conta = await _repository.getContaById(contaId);

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
      final anoMes = pagamento['ano_mes'] as int;
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

  Future<void> _pagarConta(Map<String, dynamic> pagamento) async {
    final pagamentoId = pagamento['id'];
    final contaNome = pagamento['conta_nome'];
    final valor = pagamento['valor'];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payment, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirmar Pagamento',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja pagar a conta:',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt, color: AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contaNome,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatador.moeda(valor),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Este pagamento será registrado automaticamente nos Lançamentos como uma despesa.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('PAGAR'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final result = await _repository.pagarContaComLancamento(pagamentoId);

    result.when(
      onSuccess: (sucesso) {
        if (sucesso) {
          _carregarDados();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $contaNome paga e registrada nos Lançamentos!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      onError: (erro) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(erro),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _desfazerPagamento(Map<String, dynamic> pagamento) async {
    final pagamentoId = pagamento['id'];
    final contaNome = pagamento['conta_nome'];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.undo, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            Text(
              'Desfazer Pagamento',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deseja desfazer o pagamento da conta:',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt, color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contaNome,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatador.moeda(pagamento['valor'] ?? 0),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O lançamento gerado automaticamente será removido.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('DESFAZER'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final result = await _repository.desfazerPagamento(pagamentoId);

    result.when(
      onSuccess: (sucesso) {
        if (sucesso) {
          _carregarDados();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('↩️ Pagamento de $contaNome desfeito!'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onError: (erro) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(erro),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _editarConta(Map<String, dynamic> pagamento) async {
    try {
      final contaIdRaw = pagamento['conta_id'];
      LoggerService.info('✏️ Editando conta - ID: $contaIdRaw');

      int contaId;
      if (contaIdRaw is int) {
        contaId = contaIdRaw;
      } else if (contaIdRaw is String) {
        contaId = int.parse(contaIdRaw);
      } else {
        contaId = int.tryParse(contaIdRaw.toString()) ?? 0;
      }

      if (contaId == 0) {
        LoggerService.error('❌ ID inválido');
        return;
      }

      final conta = await _repository.getContaById(contaId);

      if (conta == null) {
        LoggerService.error('❌ Conta não encontrada');
        return;
      }

      if (!mounted) return;

      final contaMap = conta.toJson();

      await AdicionarContaModal.show(
        context: context,
        conta: contaMap,
        onSalvo: () => _carregarDados(),
      );
    } catch (e) {
      LoggerService.error('❌ Erro ao editar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao editar: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _excluirConta(Map<String, dynamic> pagamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            Text(
              'Excluir Conta',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente excluir "${pagamento['conta_nome']}"?\n\nOs pagamentos futuros também serão removidos.',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _repository.deletarConta(pagamento['conta_id']);
      _carregarDados();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ ${pagamento['conta_nome']} excluída!'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatarDataVencimento(Map<String, dynamic> pagamento) {
    final anoMes = pagamento['ano_mes'] as int;
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    final dia = pagamento['dia_vencimento'] as int;
    return '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$ano';
  }

  bool _isAtrasado(Map<String, dynamic> pagamento) {
    final anoMes = pagamento['ano_mes'] as int;
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    final dia = pagamento['dia_vencimento'] as int;
    final dataVencimento = DateTime(ano, mes, dia);
    return dataVencimento.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final totalPendente = (_resumo['totalPendente'] ?? 0).toDouble();
    final totalPago = (_resumo['totalPago'] ?? 0).toDouble();
    final total = totalPendente + totalPago;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: null,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textPrimary(context),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.textPrimary(context)),
              onPressed: _carregarDados,
              tooltip: 'Atualizar',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : RefreshIndicator(
                onRefresh: _carregarDados,
                color: AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Seletor de mês
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.border(context)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon:
                                      const Icon(Icons.chevron_left, size: 18),
                                  onPressed: () => _navegarMes(-1),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
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
                                  icon:
                                      const Icon(Icons.chevron_right, size: 18),
                                  onPressed: () => _navegarMes(1),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          // Botão Adicionar
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () => AdicionarContaModal.show(
                                  context: context,
                                  onSalvo: () => _carregarDados()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.add, size: 16),
                                  SizedBox(width: 6),
                                  Text('ADICIONAR',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildResumoCard(
                              'A Pagar', totalPendente, AppColors.error),
                          const SizedBox(width: 12),
                          _buildResumoCard(
                              'Pago', totalPago, AppColors.success),
                          const SizedBox(width: 12),
                          _buildResumoCard('Total', total, AppColors.primary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _pagamentos.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt,
                                      size: 64,
                                      color: AppColors.muted(context)),
                                  const SizedBox(height: 16),
                                  Text('Nenhuma conta para este mês',
                                      style: TextStyle(
                                          color: AppColors.textSecondary(
                                              context))),
                                  const SizedBox(height: 8),
                                  Text('Clique em ADICIONAR para começar',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary(
                                              context))),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              itemCount: _pagamentos.length,
                              itemBuilder: (context, index) {
                                final pagamento = _pagamentos[index];
                                final estaPago = pagamento['status'] == 1;
                                final atrasado =
                                    !estaPago && _isAtrasado(pagamento);
                                final cor = estaPago
                                    ? AppColors.success
                                    : (atrasado
                                        ? AppColors.error
                                        : AppColors.primary);
                                final contaId = pagamento['conta_id'] as int;
                                final parcelasInfo = _parcelasCache[contaId];
                                final categoriaCor = AppColors.getCategoryColor(
                                    pagamento['categoria'] ?? 'Outros');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBackground(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.border(context)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: cor.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          estaPago
                                              ? Icons.check_circle
                                              : (atrasado
                                                  ? Icons.warning_amber_rounded
                                                  : Icons.receipt_long),
                                          color: cor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pagamento['conta_nome'] ??
                                                  'Sem nome',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary(
                                                    context),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: categoriaCor
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: categoriaCor,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        pagamento[
                                                                'categoria'] ??
                                                            'Outros',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: categoriaCor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.textSecondary(
                                                                context)
                                                            .withValues(
                                                                alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    'Vence: ${_formatarDataVencimento(pagamento)}',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: AppColors
                                                          .textSecondary(
                                                              context),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (parcelasInfo != null &&
                                                parcelasInfo['total'] > 1) ...[
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      'Parcela ${parcelasInfo['atual']}/${parcelasInfo['total']}',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  if (parcelasInfo[
                                                          'restantes'] >
                                                      0)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.warning
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Text(
                                                        'Faltam ${parcelasInfo['restantes']}',
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          color:
                                                              AppColors.warning,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            Formatador.moeda(
                                                pagamento['valor'] ?? 0),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: cor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (estaPago)
                                                GestureDetector(
                                                  onTap: () =>
                                                      _desfazerPagamento(
                                                          pagamento),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.warning
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: const Icon(Icons.undo,
                                                        size: 14,
                                                        color:
                                                            AppColors.warning),
                                                  ),
                                                ),
                                              if (!estaPago)
                                                GestureDetector(
                                                  onTap: () =>
                                                      _pagarConta(pagamento),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.success
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: const Icon(Icons.check,
                                                        size: 14,
                                                        color:
                                                            AppColors.success),
                                                  ),
                                                ),
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () =>
                                                    _editarConta(pagamento),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Icon(Icons.edit,
                                                      size: 14,
                                                      color: AppColors.primary),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () =>
                                                    _excluirConta(pagamento),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.error
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: const Icon(
                                                      Icons.delete_outline,
                                                      size: 14,
                                                      color: AppColors.error),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildResumoCard(String titulo, double valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary(context))),
            const SizedBox(height: 2),
            Text(Formatador.moeda(valor),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: cor)),
          ],
        ),
      ),
    );
  }
}
