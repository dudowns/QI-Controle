// lib/screens/transacoes_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/animated_counter.dart';
import '../widgets/toast.dart';
import '../services/theme_service.dart';
import '../services/sync_service.dart';
import 'package:intl/intl.dart';

// ✅ Modelo simples para Transacao
class Transacao {
  final int? id;
  final String ticker;
  final String tipo;
  final String tipoInvestimento;
  final double quantidade;
  final double preco;
  final double? taxa;
  final double valorTotal;
  final DateTime data;

  Transacao({
    this.id,
    required this.ticker,
    required this.tipo,
    this.tipoInvestimento = 'ACAO',
    required this.quantidade,
    required this.preco,
    this.taxa,
    required this.valorTotal,
    required this.data,
  });

  String get tipoDescricao => tipo == 'COMPRA' ? 'Compra' : 'Venda';

  factory Transacao.fromMap(Map<String, dynamic> map) {
    return Transacao(
      id: map['id'] as int?,
      ticker: map['ticker']?.toString() ?? '',
      tipo: map['tipo_transacao']?.toString() ?? 'COMPRA',
      tipoInvestimento: map['tipo_investimento']?.toString() ?? 'ACAO',
      quantidade: (map['quantidade'] as num?)?.toDouble() ?? 0,
      preco: (map['preco_unitario'] as num?)?.toDouble() ?? 0,
      taxa: (map['taxa'] as num?)?.toDouble(),
      valorTotal: (map['total'] as num?)?.toDouble() ?? 0,
      data: DateTime.parse(
          map['data']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }
}

class TransacoesScreen extends StatefulWidget {
  final String? ticker;
  final String? tipoInvestimento;

  const TransacoesScreen({
    super.key,
    this.ticker,
    this.tipoInvestimento,
  });

  @override
  State<TransacoesScreen> createState() => _TransacoesScreenState();
}

class _TransacoesScreenState extends State<TransacoesScreen> {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();

  List<Transacao> _transacoes = [];
  List<Transacao> _transacoesFiltradas = [];
  bool _loading = true;

  DateTime _mesSelecionado = DateTime.now();
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

  double _totalInvestido = 0;
  double _totalVendido = 0;
  double _saldoInvestido = 0;
  int _totalCompras = 0;
  int _totalVendas = 0;

  @override
  void initState() {
    super.initState();
    _carregarTransacoes();
  }

  Future<void> _carregarTransacoes() async {
    setState(() => _loading = true);
    try {
      final db = await _dbHelper.database;
      final query = await db.query('transacoes', orderBy: 'data DESC');

      if (widget.ticker != null) {
        _transacoes = query
            .where((t) => t['ticker'] == widget.ticker)
            .map((json) => Transacao.fromMap(json))
            .toList();
      } else {
        _transacoes = query.map((json) => Transacao.fromMap(json)).toList();
      }

      _aplicarFiltroMes();
      _calcularEstatisticas();
    } catch (e) {
      debugPrint('Erro ao carregar transações: $e');
      if (mounted) Toast.error(context, 'Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navegarMes(int delta) {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + delta,
        1,
      );
    });
    _aplicarFiltroMes();
    _calcularEstatisticas();
  }

  void _aplicarFiltroMes() {
    _transacoesFiltradas = _transacoes.where((t) {
      return t.data.year == _mesSelecionado.year &&
          t.data.month == _mesSelecionado.month;
    }).toList();
  }

  void _calcularEstatisticas() {
    double investido = 0, vendido = 0;
    int compras = 0, vendas = 0;
    for (var t in _transacoesFiltradas) {
      if (t.tipo == 'COMPRA') {
        investido += t.valorTotal;
        compras++;
      } else {
        vendido += t.valorTotal;
        vendas++;
      }
    }
    _totalInvestido = investido;
    _totalVendido = vendido;
    _saldoInvestido = investido - vendido;
    _totalCompras = compras;
    _totalVendas = vendas;
  }

  String _obterTipoPorTicker(String ticker) {
    if (ticker.endsWith('11')) return 'FII';
    if (ticker.contains('BTC') || ticker.contains('ETH')) return 'CRIPTO';
    return 'ACAO';
  }

  Future<void> _adicionarTransacao() async {
    final tickerController = TextEditingController();
    final quantidadeController = TextEditingController();
    final precoController = TextEditingController();
    final taxaController = TextEditingController(text: '0');

    String tipoSelecionado = 'COMPRA';
    String tipoInvestimento = widget.tipoInvestimento ?? 'ACAO';
    DateTime dataSelecionada = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = ThemeService().isDarkMode;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Nova Movimentação',
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: tickerController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Ticker',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: _buildTipoButton(
                          '📈 COMPRA',
                          tipoSelecionado == 'COMPRA',
                          () =>
                              setStateDialog(() => tipoSelecionado = 'COMPRA'),
                          Colors.green,
                          isDark),
                    ),
                    Expanded(
                      child: _buildTipoButton(
                          '📉 VENDA',
                          tipoSelecionado == 'VENDA',
                          () => setStateDialog(() => tipoSelecionado = 'VENDA'),
                          Colors.red,
                          isDark),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantidadeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantidade',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precoController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Preço Unitário (R\$)',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxaController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Taxa (R\$)',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: dataSelecionada,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('pt', 'BR'),
                    );
                    if (date != null)
                      setStateDialog(() => dataSelecionada = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color:
                              isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(Formatador.data(dataSelecionada),
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black)),
                          const Icon(Icons.calendar_today, size: 18),
                        ]),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final ticker = tickerController.text.trim().toUpperCase();
                  final quantidade = double.tryParse(quantidadeController.text);
                  final preco = double.tryParse(precoController.text);
                  final taxa = double.tryParse(taxaController.text) ?? 0;
                  if (ticker.isEmpty) {
                    Toast.warning(context, 'Digite o ticker');
                    return;
                  }
                  if (quantidade == null || quantidade <= 0) {
                    Toast.warning(context, 'Quantidade inválida');
                    return;
                  }
                  if (preco == null || preco <= 0) {
                    Toast.warning(context, 'Preço inválido');
                    return;
                  }
                  Navigator.pop(context, {
                    'ticker': ticker,
                    'tipo': tipoSelecionado,
                    'tipo_investimento': tipoInvestimento,
                    'quantidade': quantidade,
                    'preco': preco,
                    'taxa': taxa,
                    'data': dataSelecionada.toIso8601String(),
                  });
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                child: const Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      try {
        final db = await _dbHelper.database;
        final total = (result['quantidade'] * result['preco']) + result['taxa'];
        await db.insert('transacoes', {
          'ticker': result['ticker'],
          'tipo_investimento': result['tipo_investimento'],
          'tipo_transacao': result['tipo'],
          'quantidade': result['quantidade'],
          'preco_unitario': result['preco'],
          'taxa': result['taxa'],
          'total': total,
          'data': result['data'],
          'sync_status': 'pending',
        });
        await _carregarTransacoes();
        _dbHelper.limparCacheCompleto();
        Toast.success(context, '✅ ${result['ticker']} adicionado!');
        _syncService.syncNow();
      } catch (e) {
        Toast.error(context, 'Erro ao adicionar: $e');
      }
    }
  }

  Widget _buildTipoButton(String label, bool selected, VoidCallback onTap,
      Color color, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? color
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
      ),
    );
  }

  Future<void> _editarTransacao(Transacao transacao) async {
    final quantidadeController =
        TextEditingController(text: transacao.quantidade.toString());
    final precoController =
        TextEditingController(text: transacao.preco.toString());
    final taxaController =
        TextEditingController(text: (transacao.taxa ?? 0).toString());
    String tipoSelecionado = transacao.tipo;
    DateTime dataSelecionada = transacao.data;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = ThemeService().isDarkMode;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Editar Movimentação',
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: _buildTipoButton(
                            '📈 COMPRA',
                            tipoSelecionado == 'COMPRA',
                            () => setStateDialog(
                                () => tipoSelecionado = 'COMPRA'),
                            Colors.green,
                            isDark)),
                    Expanded(
                        child: _buildTipoButton(
                            '📉 VENDA',
                            tipoSelecionado == 'VENDA',
                            () =>
                                setStateDialog(() => tipoSelecionado = 'VENDA'),
                            Colors.red,
                            isDark)),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: quantidadeController,
                    decoration: const InputDecoration(labelText: 'Quantidade')),
                const SizedBox(height: 12),
                TextField(
                    controller: precoController,
                    decoration: const InputDecoration(
                        labelText: 'Preço Unitário', prefixText: 'R\$ ')),
                const SizedBox(height: 12),
                TextField(
                    controller: taxaController,
                    decoration: const InputDecoration(
                        labelText: 'Taxa', prefixText: 'R\$ ')),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: dataSelecionada,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null)
                      setStateDialog(() => dataSelecionada = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color:
                              isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(Formatador.data(dataSelecionada)),
                          const Icon(Icons.calendar_today, size: 18),
                        ]),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final quantidade = double.tryParse(quantidadeController.text);
                  final preco = double.tryParse(precoController.text);
                  final taxa = double.tryParse(taxaController.text) ?? 0;
                  if (quantidade == null || preco == null) {
                    Toast.error(context, 'Dados inválidos');
                    return;
                  }
                  Navigator.pop(context, {
                    'tipo': tipoSelecionado,
                    'quantidade': quantidade,
                    'preco': preco,
                    'taxa': taxa,
                    'data': dataSelecionada,
                  });
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      try {
        final db = await _dbHelper.database;
        final total = (result['quantidade'] * result['preco']) + result['taxa'];
        await db.update(
            'transacoes',
            {
              'tipo_transacao': result['tipo'],
              'quantidade': result['quantidade'],
              'preco_unitario': result['preco'],
              'taxa': result['taxa'],
              'total': total,
              'data': (result['data'] as DateTime).toIso8601String(),
              'sync_status': 'pending',
            },
            where: 'id = ?',
            whereArgs: [transacao.id]);
        await _carregarTransacoes();
        _dbHelper.limparCacheCompleto();
        Toast.success(context, '✅ Movimentação editada!');
        _syncService.syncNow();
      } catch (e) {
        Toast.error(context, 'Erro ao editar: $e');
      }
    }
  }

  Future<void> _apagarTransacao(Transacao transacao) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar'),
        content:
            Text('Apagar ${transacao.tipoDescricao} de ${transacao.ticker}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final db = await _dbHelper.database;
      await db.delete('transacoes', where: 'id = ?', whereArgs: [transacao.id]);
      await _carregarTransacoes();
      _dbHelper.limparCacheCompleto();
      Toast.success(context, '✅ Movimentação apagada!');
      _syncService.syncNow();
    } catch (e) {
      Toast.error(context, 'Erro ao apagar: $e');
    }
  }

  void _voltar() {
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  Widget _buildStatCard(String title, double value, Color color, IconData icon,
      {String? subtitle}) {
    return Expanded(
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(title,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary(context)))
              ]),
              AnimatedCounter(
                value: value,
                duration: const Duration(milliseconds: 600),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color),
                formatter: (val) => Formatador.moeda(val),
              ),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textSecondary(context))),
            ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(widget.ticker ?? 'Movimentações',
            style: TextStyle(color: AppColors.textPrimary(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary(context)),
            onPressed: _voltar),
        actions: [
          IconButton(
              icon: Icon(Icons.add, color: AppColors.textPrimary(context)),
              onPressed: _adicionarTransacao),
          IconButton(
              icon: Icon(Icons.refresh, color: AppColors.textPrimary(context)),
              onPressed: _carregarTransacoes),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.border(context)),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.chevron_left,
                                            size: 18),
                                        onPressed: () => _navegarMes(-1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints()),
                                    const SizedBox(width: 8),
                                    Text(
                                        '${_meses[_mesSelecionado.month - 1]} ${_mesSelecionado.year}',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary(
                                                context))),
                                    const SizedBox(width: 8),
                                    IconButton(
                                        icon: const Icon(Icons.chevron_right,
                                            size: 18),
                                        onPressed: () => _navegarMes(1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints()),
                                  ]),
                            ),
                          ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _adicionarTransacao,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('ADICIONAR',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        _buildStatCard('Total Investido', _totalInvestido,
                            Colors.green, Icons.trending_up,
                            subtitle: '$_totalCompras compras'),
                        const SizedBox(width: 12),
                        _buildStatCard('Total Vendido', _totalVendido,
                            Colors.red, Icons.trending_down,
                            subtitle: '$_totalVendas vendas'),
                        const SizedBox(width: 12),
                        _buildStatCard(
                            'Saldo',
                            _saldoInvestido,
                            _saldoInvestido >= 0 ? Colors.green : Colors.red,
                            Icons.account_balance_wallet),
                      ]),
                    ),
                    Expanded(
                      child: _transacoesFiltradas.isEmpty
                          ? Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long,
                                        size: 64,
                                        color: AppColors.muted(context)),
                                    const SizedBox(height: 16),
                                    Text('Nenhuma movimentação neste mês',
                                        style: TextStyle(
                                            color: AppColors.textSecondary(
                                                context))),
                                  ]),
                            )
                          : RefreshIndicator(
                              onRefresh: _carregarTransacoes,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                itemCount: _transacoesFiltradas.length,
                                itemBuilder: (context, index) {
                                  final t = _transacoesFiltradas[index];
                                  final isCompra = t.tipo == 'COMPRA';
                                  final cor = isCompra
                                      ? AppColors.success
                                      : AppColors.error;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    color: AppColors.cardBackground(context),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: cor.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                              isCompra
                                                  ? Icons.trending_up
                                                  : Icons.trending_down,
                                              color: cor),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  Text(t.ticker,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: cor.withValues(
                                                          alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                        isCompra
                                                            ? 'COMPRA'
                                                            : 'VENDA',
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            color: cor)),
                                                  ),
                                                ]),
                                                Text(
                                                    '${t.quantidade.toStringAsFixed(2)} × ${Formatador.moeda(t.preco)}',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary(
                                                                context))),
                                                Text(Formatador.data(t.data),
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .textSecondary(
                                                                context))),
                                              ]),
                                        ),
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                  Formatador.moeda(
                                                      t.valorTotal),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: cor)),
                                              const SizedBox(height: 8),
                                              Row(children: [
                                                GestureDetector(
                                                  onTap: () =>
                                                      _editarTransacao(t),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: const Icon(
                                                        Icons.edit,
                                                        size: 16,
                                                        color:
                                                            AppColors.primary),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _apagarTransacao(t),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.error
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: const Icon(
                                                        Icons.delete_outline,
                                                        size: 16,
                                                        color: AppColors.error),
                                                  ),
                                                ),
                                              ]),
                                            ]),
                                      ]),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ]),
            ),
    );
  }
}
