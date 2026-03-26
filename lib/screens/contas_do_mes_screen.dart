// lib/screens/contas_do_mes_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/pagamento_model.dart';
import '../constants/app_colors.dart';
import '../widgets/adicionar_conta_modal.dart'; // 🔥 NOVO IMPORT!

class ContasDoMesScreen extends StatefulWidget {
  const ContasDoMesScreen({super.key});

  @override
  State<ContasDoMesScreen> createState() => _ContasDoMesScreenState();
}

class _ContasDoMesScreenState extends State<ContasDoMesScreen> {
  final DBHelper _dbHelper = DBHelper();
  DateTime _mesSelecionado = DateTime.now();
  List<PagamentoMes> _pagamentos = [];
  Map<String, dynamic> _resumo = {};
  bool _carregando = true;

  // FILTROS
  bool _filtroParcelas = false;
  bool _filtroApenasPendentes = false;
  String _filtroCategoria = 'Todas';
  List<String> _categorias = ['Todas'];

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
    _carregarDados();
  }

  Future<void> _carregarCategorias() async {
    try {
      final db = await _dbHelper.database;
      final result =
          await db.query('contas', distinct: true, columns: ['categoria']);

      final categorias = result
          .map((c) => c['categoria'] as String)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();

      setState(() {
        _categorias = ['Todas', ...categorias];
      });
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
    }
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    try {
      final pagamentosJson = await _dbHelper.getPagamentosDoMes(
        _mesSelecionado.year,
        _mesSelecionado.month,
      );

      _pagamentos = pagamentosJson
          .map((p) {
            try {
              return PagamentoMes.fromJson(p);
            } catch (e) {
              return null;
            }
          })
          .whereType<PagamentoMes>()
          .toList();

      _resumo = await _dbHelper.getResumoContasDoMes(
        _mesSelecionado.year,
        _mesSelecionado.month,
      );
    } catch (e) {
      _pagamentos = [];
      _resumo = {
        'totalPendente': 0,
        'qtdPendente': 0,
        'totalPago': 0,
        'qtdPago': 0,
      };
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  // 🟢 FUNÇÃO CORRIGIDA - CALCULA PARCELAS DIREITO!
  Future<Map<String, dynamic>> _getInfoParcelas(int contaId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'contas',
        where: 'id = ?',
        whereArgs: [contaId],
      );

      if (result.isEmpty) return {};

      final conta = result.first;

      // Pega os dados da conta
      final totalParcelas = conta['parcelas_total'] as int?;
      final dataInicioStr = conta['data_inicio'] as String?;
      final categoria = conta['categoria'] as String? ?? 'Outros';

      debugPrint(
          '🔍 Dados da conta $contaId: totalParcelas=$totalParcelas, dataInicio=$dataInicioStr');

      // Se não tem parcela, retorna só categoria
      if (totalParcelas == null || totalParcelas <= 1) {
        return {'categoria': categoria};
      }

      // Se não tem data de início, retorna só categoria
      if (dataInicioStr == null) {
        return {'categoria': categoria};
      }

      final dataInicio = DateTime.parse(dataInicioStr);

      // Calcula a diferença de meses
      int mesesDiferenca = (_mesSelecionado.year - dataInicio.year) * 12 +
          (_mesSelecionado.month - dataInicio.month);

      // Parcela atual = mesesDiferenca + 1
      int parcelaAtual = mesesDiferenca + 1;

      debugPrint(
          '📅 Mês selecionado: ${_mesSelecionado.month}/${_mesSelecionado.year}');
      debugPrint('📅 Data início: ${dataInicio.month}/${dataInicio.year}');
      debugPrint('🧮 Meses diferença: $mesesDiferenca');
      debugPrint('🔢 Parcela atual calculada: $parcelaAtual');

      // Se ainda não começou
      if (parcelaAtual < 1) {
        return {
          'atual': 1,
          'total': totalParcelas,
          'restantes': totalParcelas,
          'categoria': categoria,
          'concluido': false,
          'status': 'A começar'
        };
      }

      // Se já passou do total
      if (parcelaAtual > totalParcelas) {
        return {
          'atual': totalParcelas,
          'total': totalParcelas,
          'restantes': 0,
          'categoria': categoria,
          'concluido': true, // SÓ AQUI É TRUE!
          'status': 'Concluído'
        };
      }

      // Tá no meio do parcelamento
      return {
        'atual': parcelaAtual,
        'total': totalParcelas,
        'restantes': totalParcelas - parcelaAtual,
        'categoria': categoria,
        'concluido': false,
        'status': 'Em andamento'
      };
    } catch (e) {
      debugPrint('❌ Erro ao calcular parcelas: $e');
      return {};
    }
  }

  String _formatarValor(double valor) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ').format(valor);

  void _navegarMes(int delta) {
    setState(() => _mesSelecionado = DateTime(
          _mesSelecionado.year,
          _mesSelecionado.month + delta,
          1,
        ));
    _carregarDados();
  }

  Future<void> _pagarConta(PagamentoMes pagamento) async {
    final sucesso = await _dbHelper.pagarConta(pagamento.id!);
    if (sucesso && mounted) {
      _carregarDados();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${pagamento.contaNome} paga!'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _excluirConta(int contaId, String nomeConta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text(
          'Excluir Conta',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        content: Text(
          'Deseja realmente excluir a conta "$nomeConta"?\n\nTodos os pagamentos futuros serão removidos.',
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
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _dbHelper.deletarConta(contaId);
        if (mounted) {
          _carregarDados();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('🗑️ Conta "$nomeConta" excluída!'),
            backgroundColor: Colors.orange,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
  }

  List<PagamentoMes> _getPagamentosFiltrados() {
    var filtrados = List<PagamentoMes>.from(_pagamentos);
    if (_filtroApenasPendentes) {
      filtrados = filtrados.where((p) => !p.estaPago).toList();
    }
    return filtrados;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        toolbarHeight: 50,
        title: const Text('Contas do Mês', style: TextStyle(fontSize: 18)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _filtroApenasPendentes ? Icons.pending : Icons.pending_outlined,
              color: _filtroApenasPendentes ? Colors.orange : Colors.white70,
            ),
            onPressed: () {
              setState(() => _filtroApenasPendentes = !_filtroApenasPendentes);
            },
          ),
          IconButton(
            icon: Icon(
              _filtroParcelas ? Icons.repeat : Icons.repeat_outlined,
              color: _filtroParcelas ? Colors.amber : Colors.white70,
            ),
            onPressed: () {
              setState(() => _filtroParcelas = !_filtroParcelas);
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.white70),
            onSelected: (String value) {
              setState(() => _filtroCategoria = value);
            },
            itemBuilder: (context) {
              return _categorias.map((categoria) {
                return PopupMenuItem(
                  value: categoria,
                  child: Row(
                    children: [
                      if (categoria == _filtroCategoria)
                        Icon(Icons.check, color: AppColors.primary, size: 16),
                      if (categoria == _filtroCategoria) SizedBox(width: 8),
                      Text(
                        categoria,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: _carregando
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 18),
                          onPressed: () => _navegarMes(-1),
                          color: AppColors.primary,
                        ),
                        Text(
                          DateFormat('MMMM yyyy', 'pt_BR')
                              .format(_mesSelecionado)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          onPressed: () => _navegarMes(1),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      _buildResumoCardAPagar(),
                      const SizedBox(width: 12),
                      _buildResumoCardPago(),
                    ],
                  ),
                ),
                if (_filtroParcelas ||
                    _filtroApenasPendentes ||
                    _filtroCategoria != 'Todas')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_filtroParcelas)
                          Chip(
                            label: const Text('Parcelas'),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _filtroParcelas = false);
                            },
                          ),
                        if (_filtroApenasPendentes)
                          Chip(
                            label: const Text('Pendentes'),
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _filtroApenasPendentes = false);
                            },
                          ),
                        if (_filtroCategoria != 'Todas')
                          Chip(
                            label: Text(_filtroCategoria),
                            backgroundColor: Colors.purple.withOpacity(0.1),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _filtroCategoria = 'Todas');
                            },
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _getPagamentosFiltrados().isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: _getPagamentosFiltrados().length,
                          itemBuilder: (context, index) {
                            final pagamento = _getPagamentosFiltrados()[index];
                            return _buildContaCard(pagamento);
                          },
                        ),
                ),
              ],
            ),
      // 🔥 FAB AGORA USA O MODAL!
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          AdicionarContaModal.show(
            context: context,
            onSalvo: () {
              _carregarDados();
            },
          );
        },
      ),
    );
  }

  Widget _buildResumoCardAPagar() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A PAGAR',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(_formatarValor(_resumo['totalPendente'] ?? 0),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(
                '${_resumo['qtdPendente'] ?? 0} ${_resumo['qtdPendente'] == 1 ? 'conta' : 'contas'}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoCardPago() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PAGO',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
            const SizedBox(height: 2),
            Text(
              _formatarValor(_resumo['totalPago'] ?? 0),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context)),
            ),
            Text(
              '${_resumo['qtdPago'] ?? 0} ${_resumo['qtdPago'] == 1 ? 'conta' : 'contas'}',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }

  // 🟢 CARD PRINCIPAL - COM PARCELAS CORRETAS!
  Widget _buildContaCard(PagamentoMes pagamento) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getInfoParcelas(pagamento.contaId),
      builder: (context, snapshot) {
        final infoParcelas = snapshot.data ?? {};
        final temParcelas = infoParcelas.isNotEmpty;
        final parcelaAtual = infoParcelas['atual'] as int?;
        final totalParcelas = infoParcelas['total'] as int?;
        final parcelasRestantes = infoParcelas['restantes'] as int?;
        final concluido = infoParcelas['concluido'] == true;
        final categoria = infoParcelas['categoria'] ?? 'Outros';

        if (_filtroParcelas && !temParcelas) {
          return const SizedBox.shrink();
        }

        if (_filtroCategoria != 'Todas' && categoria != _filtroCategoria) {
          return const SizedBox.shrink();
        }

        final atrasado = pagamento.estaAtrasado && !pagamento.estaPago;
        final Color corCategoria = AppColors.getCategoryColor(categoria);
        final cor = pagamento.estaPago
            ? AppColors.success
            : (atrasado ? AppColors.error : corCategoria);
        final corFundo = pagamento.estaPago
            ? AppColors.successLight
            : (atrasado ? AppColors.errorLight : corCategoria.withOpacity(0.1));

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: corFundo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  pagamento.estaPago
                      ? Icons.check_circle
                      : (atrasado ? Icons.warning_amber : Icons.receipt),
                  color: cor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pagamento.contaNome,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Linha da categoria
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: corCategoria,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          categoria,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // 🟢 LINHA DAS PARCELAS - CORRIGIDA!
                    if (temParcelas && totalParcelas != null)
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (concluido) ...[
                            // ✅ Caso 1: Já acabou
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Concluído',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // 🔁 Caso 2: Ainda tem parcelas
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.repeat,
                                      size: 12, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    parcelaAtual != null
                                        ? '$parcelaAtual/$totalParcelas'
                                        : '0/$totalParcelas',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),

                            if (parcelasRestantes != null &&
                                parcelasRestantes > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Faltam $parcelasRestantes',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),

                    const SizedBox(height: 4),

                    // Data de vencimento
                    Text(
                      'Vence ${pagamento.dataVencimentoFormatada}',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatarValor(pagamento.valor),
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: cor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!pagamento.estaPago)
                        SizedBox(
                          width: 60,
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () => _pagarConta(pagamento),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                              elevation: 0,
                              minimumSize: const Size(60, 28),
                            ),
                            child: const Text('PAGAR',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: Colors.red[300],
                        onPressed: () => _excluirConta(
                            pagamento.contaId, pagamento.contaNome),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_outlined,
              size: 56, color: AppColors.muted(context)),
          const SizedBox(height: 12),
          Text(
            'Nenhuma conta para este mês',
            style: TextStyle(
                fontSize: 15, color: AppColors.textSecondary(context)),
          ),
          if (_filtroParcelas ||
              _filtroApenasPendentes ||
              _filtroCategoria != 'Todas')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _filtroParcelas = false;
                    _filtroApenasPendentes = false;
                    _filtroCategoria = 'Todas';
                  });
                },
                child: Text(
                  'Limpar filtros',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // 🔥 BOTÃO DO EMPTY STATE AGORA USA MODAL!
          ElevatedButton.icon(
            onPressed: () {
              AdicionarContaModal.show(
                context: context,
                onSalvo: () {
                  _carregarDados();
                },
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('ADICIONAR CONTA',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
