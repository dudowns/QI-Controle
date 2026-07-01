// lib/screens/proventos.dart - VERSÃO FINAL CORRIGIDA
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

import '../constants/app_colors.dart';
import '../widgets/app_modals.dart';
import '../widgets/toast.dart';

class ProventosScreen extends StatefulWidget {
  const ProventosScreen({super.key});

  @override
  State<ProventosScreen> createState() => _ProventosScreenState();
}

class _ProventosScreenState extends State<ProventosScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Provento> _proventos = [];
  List<Provento> _filteredProventos = [];
  List<String> _tickersDisponiveis = [];

  bool _isLoading = true;
  bool _isDisposed = false;

  String _selectedPeriod = '12M';
  String _searchQuery = '';
  String _sortBy = 'date';

  final TextEditingController _searchController = TextEditingController();

  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormatter = DateFormat('dd/MM/yy');
  final List<String> _periodos = ['1M', '3M', '6M', '12M', 'ALL'];

  static const Map<String, String> _tiposProvento = {
    'DIVIDENDO': 'Dividendo',
    'JCP': 'JCP',
    'RENDIMENTO': 'Rendimento',
    'BONIFICACAO': 'Bonificação',
    'OUTROS': 'Outros',
  };

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _carregarDados();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    if (_isDisposed || !mounted) return;
    setState(() => _isLoading = true);

    try {
      final resultados = await Future.wait([
        _supabase.from('investments').select('ticker').order('ticker'),
        _supabase
            .from('proventos')
            .select()
            .order('data_pagamento', ascending: false),
      ]);

      if (_isDisposed || !mounted) return;

      final listaTickers = (resultados[0] as List)
          .map((e) => e['ticker'].toString().toUpperCase())
          .toSet()
          .toList();
      listaTickers.sort();

      final listaProventos = (resultados[1] as List)
          .map((json) => Provento.fromJson(json))
          .toList();

      setState(() {
        _tickersDisponiveis = listaTickers;
        _proventos = listaProventos;
        _aplicarFiltros();
        _isLoading = false;
      });
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
        Toast.error(context, 'Erro ao carregar dados');
      }
    }
  }

  void _aplicarFiltros() {
    if (_isDisposed || !mounted) return;

    List<Provento> resultado = List.from(_proventos);

    if (_selectedPeriod != 'ALL') {
      final meses = int.parse(_selectedPeriod.replaceAll('M', ''));
      final agora = DateTime.now();
      final dataCorte = DateTime(agora.year, agora.month - meses + 1, 1);
      resultado =
          resultado.where((p) => !p.dataPagamento.isBefore(dataCorte)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      resultado = resultado.where((p) {
        return p.ticker.toLowerCase().contains(query) ||
            (_tiposProvento[p.tipoProvento] ?? p.tipoProvento)
                .toLowerCase()
                .contains(query);
      }).toList();
    }

    resultado.sort((a, b) {
      switch (_sortBy) {
        case 'amount':
          return b.totalRecebido.compareTo(a.totalRecebido);
        case 'ticker':
          final comp = a.ticker.compareTo(b.ticker);
          return comp != 0 ? comp : b.dataPagamento.compareTo(a.dataPagamento);
        default:
          return b.dataPagamento.compareTo(a.dataPagamento);
      }
    });

    setState(() => _filteredProventos = resultado);
  }

  Map<String, double> _calcularEstatisticas() {
    double recebido = 0;
    double pendente = 0;

    for (var p in _filteredProventos) {
      if (p.isFuture) {
        pendente += p.totalRecebido;
      } else {
        recebido += p.totalRecebido;
      }
    }

    return {'recebido': recebido, 'pendente': pendente};
  }

  List<Map<String, dynamic>> _getDadosAgrupados() {
    final Map<String, double> mapa = {};
    for (var p in _filteredProventos.where((p) => !p.isFuture)) {
      mapa[p.ticker] = (mapa[p.ticker] ?? 0.0) + p.totalRecebido;
    }

    if (mapa.isEmpty) return [];

    final lista =
        mapa.entries.map((e) => {'ticker': e.key, 'valor': e.value}).toList();
    lista
        .sort((a, b) => (b['valor'] as double).compareTo(a['valor'] as double));
    return lista;
  }

  List<PieChartSectionData> _buildChartSections(
      List<Map<String, dynamic>> dados) {
    if (dados.isEmpty) {
      return [
        PieChartSectionData(
            color: Colors.grey.withOpacity(0.15),
            value: 1,
            radius: 8,
            showTitle: false)
      ];
    }

    final cores = [
      AppColors.primary,
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899)
    ];
    final top5 = dados.take(5).toList();

    return List.generate(top5.length, (index) {
      return PieChartSectionData(
          value: top5[index]['valor'],
          color: cores[index % cores.length],
          radius: 10,
          showTitle: false);
    });
  }

  Future<void> _abrirFormulario([Provento? provento]) async {
    Map<String, dynamic>? dados;
    if (provento != null) {
      dados = {
        'ticker': provento.ticker,
        'tipo_provento': provento.tipoProvento,
        'valor_por_cota': provento.valorPorCota,
        'quantidade': provento.quantidade,
        'data_pagamento': provento.dataPagamento.toIso8601String(),
        'data_com': provento.dataCom?.toIso8601String(),
        'observacao': provento.observacao,
      };
    }

    final res = await AppModals.mostrarModalProvento(
      context: context,
      provento: dados,
      tickersDisponiveis: _tickersDisponiveis,
    );

    if (res != null && mounted) {
      await _salvarProvento(res, provento);
    }
  }

  Future<void> _salvarProvento(
      Map<String, dynamic> dados, Provento? provento) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        Toast.error(context, 'Usuário não autenticado');
        return;
      }

      final valorPorCota = (dados['valor_por_cota'] as num).toDouble();
      final quantidade = (dados['quantidade'] as num?)?.toDouble() ?? 1.0;

      final payload = {
        'user_id': user.id,
        'ticker': dados['ticker'].toString().toUpperCase(),
        'tipo_provento': dados['tipo_provento'] ?? 'DIVIDENDO',
        'valor_por_cota': valorPorCota,
        'quantidade': quantidade,
        'total_recebido': valorPorCota * quantidade,
        'data_pagamento': dados['data_pagamento'],
        'data_com': dados['data_com'],
        'observacao': dados['observacao'],
        'sync_status': 'pending',
      };

      if (provento != null) {
        await _supabase.from('proventos').update(payload).eq('id', provento.id);
        Toast.success(context, '✅ Provento atualizado!');
      } else {
        await _supabase.from('proventos').insert(payload);
        Toast.success(context, '✅ Provento adicionado!');
      }

      await _carregarDados();
    } catch (e) {
      Toast.error(context, 'Erro ao salvar provento');
    }
  }

  Future<void> _excluir(Provento provento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir provento'),
        content: Text('Remover provento de ${provento.ticker}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir')),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _supabase.from('proventos').delete().eq('id', provento.id);
        Toast.success(context, '✅ Provento excluído!');
        await _carregarDados();
      } catch (e) {
        Toast.error(context, 'Erro ao excluir');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calcularEstatisticas();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text('Meus Proventos',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
              onPressed: _carregarDados,
              icon: Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary(context), size: 22)),
          IconButton(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.primary, size: 26)),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: FadeInDown(child: _buildCompactDashboard(stats))),
                SliverPersistentHeader(
                    pinned: true,
                    delegate: _HeaderDelegate(
                        height: 115, child: _buildFilterSection())),
                if (_filteredProventos.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildSlimCard(_filteredProventos[index], index),
                        childCount: _filteredProventos.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildCompactDashboard(Map<String, double> stats) {
    final dadosPie = _getDadosAgrupados();
    final total = (stats['recebido'] ?? 0.0) + (stats['pendente'] ?? 0.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          SizedBox(
              height: 100,
              width: 100,
              child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 28,
                  sections: _buildChartSections(dadosPie)))),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PATRIMÔNIO EM PROVENTOS',
                    style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(_currencyFormatter.format(total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 14),
                _buildSummaryRow(
                    'Recebido', stats['recebido'] ?? 0, Colors.green),
                const SizedBox(height: 5),
                _buildSummaryRow(
                    'A Receber', stats['pendente'] ?? 0, Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double valor, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 10)),
        ]),
        Text(_currencyFormatter.format(valor),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: AppColors.background(context),
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _periodos.map((p) {
                final isSel = _selectedPeriod == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedPeriod = p);
                      _aplicarFiltros();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primary
                            : AppColors.cardBackground(context),
                        borderRadius: BorderRadius.circular(10),
                        border: isSel
                            ? null
                            : Border.all(
                                color:
                                    AppColors.border(context).withValues(alpha: 0.3)),
                      ),
                      child: Text(p == 'ALL' ? 'TUDO' : p,
                          style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : AppColors.textSecondary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                        color: AppColors.cardBackground(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.border(context).withValues(alpha: 0.2))),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        setState(() => _searchQuery = v);
                        _aplicarFiltros();
                      },
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Buscar ticker...',
                        hintStyle: TextStyle(
                            color: AppColors.textSecondary(context)
                                .withValues(alpha: 0.5),
                            fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 16, color: AppColors.textSecondary(context)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary(context)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _aplicarFiltros();
                                })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    HapticFeedback.lightImpact();
                    setState(() => _sortBy = value);
                    _aplicarFiltros();
                  },
                  color: AppColors.surface(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                        color: AppColors.cardBackground(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.border(context).withValues(alpha: 0.2))),
                    child: Icon(Icons.sort_rounded,
                        size: 20, color: AppColors.textSecondary(context)),
                  ),
                  itemBuilder: (context) => [
                    _buildPopupItem('Data', 'date', Icons.calendar_today),
                    _buildPopupItem('Valor', 'amount', Icons.attach_money),
                    _buildPopupItem('Ticker', 'ticker', Icons.tag),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon,
            size: 18,
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary(context)),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textPrimary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13)),
        if (isSelected) ...[
          const Spacer(),
          const Icon(Icons.check, size: 16, color: AppColors.primary)
        ],
      ]),
    );
  }

  Widget _buildSlimCard(Provento provento, int index) {
    final bool eFuturo = provento.isFuture;
    final Color accentColor =
        eFuturo ? const Color(0xFF3B82F6) : const Color(0xFF10B981);

    return FadeInLeft(
      duration: const Duration(milliseconds: 300),
      delay: Duration(milliseconds: index * 30),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: AppColors.cardBackground(context),
            borderRadius: BorderRadius.circular(15),
            border:
                Border.all(color: AppColors.border(context).withValues(alpha: 0.1))),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _abrirFormulario(provento),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                      provento.ticker.isNotEmpty
                          ? provento.ticker[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provento.ticker,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary(context))),
                      const SizedBox(height: 3),
                      Row(children: [
                        _buildMiniBadge(
                            _tiposProvento[provento.tipoProvento] ??
                                provento.tipoProvento,
                            AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(_dateFormatter.format(provento.dataPagamento),
                            style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 10)),
                        if (eFuturo) ...[
                          const SizedBox(width: 6),
                          _buildMiniBadge('A receber', const Color(0xFF3B82F6))
                        ],
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_currencyFormatter.format(provento.totalRecebido),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _buildMiniIconButton(
                          Icons.edit_rounded,
                          Colors.grey.shade400,
                          () => _abrirFormulario(provento)),
                      const SizedBox(width: 8),
                      _buildMiniIconButton(Icons.delete_outline_rounded,
                          Colors.red.shade300, () => _excluir(provento)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMiniIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 17, color: color)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.payments_outlined,
              size: 48,
              color: AppColors.textSecondary(context).withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Nenhum provento',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context))),
          const SizedBox(height: 4),
          Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhum resultado para "$_searchQuery"'
                  : 'Toque em + para adicionar',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary(context))),
        ]),
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _HeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;
  @override
  bool shouldRebuild(_HeaderDelegate oldDelegate) => true;
}

class Provento {
  final String id;
  final String ticker;
  final String tipoProvento;
  final double valorPorCota;
  final double? quantidade;
  final double totalRecebido;
  final DateTime dataPagamento;
  final DateTime? dataCom;
  final bool isFuture;
  final String? observacao;

  Provento(
      {required this.id,
      required this.ticker,
      required this.tipoProvento,
      required this.valorPorCota,
      this.quantidade,
      required this.totalRecebido,
      required this.dataPagamento,
      this.dataCom,
      required this.isFuture,
      this.observacao});

  factory Provento.fromJson(Map<String, dynamic> json) {
    final d = json['data_pagamento'] != null
        ? DateTime.parse(json['data_pagamento'].toString())
        : DateTime.now();
    DateTime? dataCom;
    try {
      dataCom = json['data_com'] != null
          ? DateTime.parse(json['data_com'].toString())
          : null;
    } catch (_) {
      dataCom = null;
    }

    return Provento(
      id: json['id'].toString(),
      ticker: json['ticker']?.toString() ?? '',
      tipoProvento: json['tipo_provento']?.toString() ?? 'DIVIDENDO',
      valorPorCota: (json['valor_por_cota'] as num?)?.toDouble() ?? 0.0,
      quantidade: (json['quantidade'] as num?)?.toDouble(),
      totalRecebido: (json['total_recebido'] as num?)?.toDouble() ?? 0.0,
      dataPagamento: d,
      dataCom: dataCom,
      isFuture: d.isAfter(DateTime.now()),
      observacao: json['observacao']?.toString(),
    );
  }
}
