// lib/screens/proventos.dart - VERSÃO FINAL COMPLETA E CORRIGIDA
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  bool _isLoading = true;
  bool _isSyncing = false;
  String _selectedPeriod = '12M';
  String _searchQuery = '';
  String _sortBy = 'date';
  bool _isDisposed = false;
  bool _showChart = true;

  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormatter = DateFormat('dd/MM/yyyy');

  final List<String> _periodos = ['1M', '3M', '6M', '12M', 'ALL'];
  final Map<String, String> _tiposProvento = {
    'DIVIDENDO': 'Dividendo',
    'JCP': 'JCP',
    'RENDIMENTO': 'Rendimento',
    'BONIFICACAO': 'Bonificação',
    'OUTROS': 'Outros',
  };

  List<String> _tickersDisponiveis = [];

  final List<Color> _chartColors = [
    const Color(0xFF8B5CF6),
    const Color(0xFF3B82F6),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFFEC4899),
    const Color(0xFF6366F1),
    const Color(0xFF14B8A6),
  ];

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _carregarTudo();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _carregarTudo() async {
    await _carregarTickers();
    await _carregarProventos();
  }

  Future<void> _carregarTickers() async {
    try {
      final response = await _supabase
          .from('investimentos')
          .select('ticker')
          .order('ticker');

      if (!_isDisposed && mounted) {
        final tickers = response
            .map((item) => item['ticker'].toString().toUpperCase())
            .toSet()
            .toList();
        tickers.sort();

        setState(() {
          _tickersDisponiveis = tickers;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erro ao carregar tickers: $e');
    }
  }

  Future<void> _carregarProventos() async {
    if (_isDisposed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('proventos')
          .select()
          .order('data_pagamento', ascending: false);

      if (!_isDisposed && mounted) {
        final proventos =
            response.map((json) => Provento.fromJson(json)).toList();

        setState(() {
          _proventos = proventos;
          _aplicarFiltros();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
        Toast.error(context, 'Erro ao carregar proventos');
      }
    }
  }

  void _aplicarFiltros() {
    List<Provento> resultado = List.from(_proventos);

    if (_selectedPeriod != 'ALL') {
      final meses = int.parse(_selectedPeriod.replaceAll('M', ''));
      final dataCorte = DateTime.now().subtract(Duration(days: meses * 30));
      resultado =
          resultado.where((p) => p.dataPagamento.isAfter(dataCorte)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      resultado = resultado
          .where((p) =>
              p.ticker.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    resultado.sort((a, b) {
      switch (_sortBy) {
        case 'date':
          return b.dataPagamento.compareTo(a.dataPagamento);
        case 'amount':
          return b.totalRecebido.compareTo(a.totalRecebido);
        case 'ticker':
          return a.ticker.compareTo(b.ticker);
        default:
          return 0;
      }
    });

    if (!_isDisposed && mounted) {
      setState(() {
        _filteredProventos = resultado;
      });
    }
  }

  List<Map<String, dynamic>> get _dadosGrafico {
    final Map<String, double> porTicker = {};

    for (var p in _filteredProventos) {
      porTicker[p.ticker] = (porTicker[p.ticker] ?? 0) + p.totalRecebido;
    }

    final total = porTicker.values.fold(0.0, (a, b) => a + b);

    return porTicker.entries.map((entry) {
      return {
        'ticker': entry.key,
        'valor': entry.value,
        'percentual': total > 0 ? (entry.value / total) * 100 : 0,
      };
    }).toList()
      ..sort((a, b) => (b['valor'] as double).compareTo(a['valor'] as double));
  }

  Future<void> _mostrarFormulario([Provento? provento]) async {
    Map<String, dynamic>? dadosProvento;

    if (provento != null) {
      dadosProvento = {
        'ticker': provento.ticker,
        'tipo_provento': provento.tipoProvento,
        'valor_por_cota': provento.valorPorCota,
        'quantidade': provento.quantidade ?? 1,
        'data_pagamento': provento.dataPagamento.toIso8601String(),
        'data_com': provento.dataCom?.toIso8601String(),
        'observacao': provento.observacao,
      };
    }

    final resultado = await AppModals.mostrarModalProvento(
      context: context,
      provento: dadosProvento,
      tickersDisponiveis: _tickersDisponiveis,
    );

    if (resultado != null && mounted) {
      await _salvarProvento(resultado, provento);
    }
  }

  Future<void> _salvarProvento(Map<String, dynamic> dados,
      [Provento? provento]) async {
    if (_isDisposed || !mounted) return;

    setState(() => _isSyncing = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        Toast.error(context, 'Usuário não autenticado');
        return;
      }

      final valorPorCota = (dados['valor_por_cota'] as num).toDouble();
      final quantidade = (dados['quantidade'] as num?)?.toDouble() ?? 1.0;
      final totalRecebido = valorPorCota * quantidade;

      final data = {
        'user_id': user.id,
        'ticker': dados['ticker'].toString().toUpperCase(),
        'tipo_provento': dados['tipo_provento'] ?? 'DIVIDENDO',
        'valor_por_cota': valorPorCota,
        'quantidade': quantidade,
        'total_recebido': totalRecebido,
        'data_pagamento': dados['data_pagamento'],
        'data_com': dados['data_com'],
        'sync_status': 'pending',
      };

      if (provento != null) {
        await _supabase.from('proventos').update(data).eq('id', provento.id);
        Toast.success(context, '✅ Provento atualizado!');
      } else {
        await _supabase.from('proventos').insert(data);
        Toast.success(context, '✅ Provento adicionado!');
      }

      await _carregarProventos();
    } catch (e) {
      Toast.error(context, 'Erro ao salvar');
    } finally {
      if (!_isDisposed && mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _deletarProvento(Provento provento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Excluir provento de ${provento.ticker}?'),
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

    if (confirmar != true) return;

    try {
      await _supabase.from('proventos').delete().eq('id', provento.id);
      Toast.success(context, '✅ Provento excluído!');
      await _carregarProventos();
    } catch (e) {
      Toast.error(context, 'Erro ao excluir');
    }
  }

  Map<String, dynamic> _calcularEstatisticas() {
    final total =
        _filteredProventos.fold(0.0, (sum, p) => sum + p.totalRecebido);
    final passados = _filteredProventos.where((p) => !p.isFuture).toList();
    final futuros = _filteredProventos.where((p) => p.isFuture).toList();

    final totalPassado = passados.fold(0.0, (sum, p) => sum + p.totalRecebido);
    final totalFuturo = futuros.fold(0.0, (sum, p) => sum + p.totalRecebido);
    final media =
        _filteredProventos.isEmpty ? 0 : total / _filteredProventos.length;

    return {
      'total': total,
      'totalPassado': totalPassado,
      'totalFuturo': totalFuturo,
      'media': media,
      'quantidade': _filteredProventos.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calcularEstatisticas();
    final dadosGrafico = _dadosGrafico;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: AppColors.textSecondary(context),
                      size: 22,
                    ),
                    onPressed: _carregarTudo,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    onPressed: () => _mostrarFormulario(),
                  ),
                ],
              ),
            ),

            // Filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _periodos.map((periodo) {
                          final isSelected = _selectedPeriod == periodo;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedPeriod = periodo);
                                _aplicarFiltros();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                          .withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                            .withValues(alpha: 0.3)
                                        : AppColors.divider(context)
                                            .withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  periodo == 'ALL' ? 'Todos' : periodo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() => _sortBy = value);
                      _aplicarFiltros();
                    },
                    color: AppColors.surface(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.sort_rounded,
                        size: 20,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'date',
                        child: Text('Por data',
                            style: TextStyle(
                                color: AppColors.textPrimary(context))),
                      ),
                      PopupMenuItem(
                        value: 'amount',
                        child: Text('Por valor',
                            style: TextStyle(
                                color: AppColors.textPrimary(context))),
                      ),
                      PopupMenuItem(
                        value: 'ticker',
                        child: Text('Por ticker',
                            style: TextStyle(
                                color: AppColors.textPrimary(context))),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Busca
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar ticker...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.textSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surface(context),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary(context),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _aplicarFiltros();
                },
              ),
            ),

            const SizedBox(height: 12),

            // Cards de estatísticas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Recebido',
                      _currencyFormatter.format(stats['totalPassado']),
                      Icons.trending_down,
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'A Receber',
                      _currencyFormatter.format(stats['totalFuturo']),
                      Icons.calendar_today,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Média',
                      _currencyFormatter.format(stats['media']),
                      Icons.equalizer,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Gráfico de Pizza
            if (dadosGrafico.isNotEmpty && _filteredProventos.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.border(context), width: 0.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Distribuição por Ativo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showChart
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 20,
                            color: AppColors.textSecondary(context),
                          ),
                          onPressed: () {
                            setState(() => _showChart = !_showChart);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (_showChart) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        child: Row(
                          children: [
                            // Gráfico
                            Expanded(
                              flex: 1,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 30,
                                  sections: dadosGrafico
                                      .take(6)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final valor = item['valor'] as double;
                                    final percentual =
                                        item['percentual'] as double;

                                    return PieChartSectionData(
                                      value: valor,
                                      color: _chartColors[
                                          index % _chartColors.length],
                                      title: percentual > 5
                                          ? '${percentual.toStringAsFixed(0)}%'
                                          : '',
                                      titleStyle: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      radius: 45,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            // Legenda
                            Expanded(
                              flex: 1,
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: dadosGrafico.take(6).length,
                                itemBuilder: (context, index) {
                                  final item = dadosGrafico[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _chartColors[
                                                index % _chartColors.length],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item['ticker'],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary(
                                                  context),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _currencyFormatter
                                              .format(item['valor']),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                AppColors.textPrimary(context),
                                          ),
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
                    ],
                  ],
                ),
              ),

            if (dadosGrafico.isNotEmpty) const SizedBox(height: 8),

            // Lista de proventos
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProventos.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _carregarTudo,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _filteredProventos.length,
                            itemBuilder: (context, index) {
                              final provento = _filteredProventos[index];
                              return FadeInLeft(
                                delay: Duration(milliseconds: index * 30),
                                child: _buildProventoCard(provento),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProventoCard(Provento provento) {
    final isFuture = provento.isFuture;
    final iconColor =
        isFuture ? const Color(0xFF3B82F6) : const Color(0xFF10B981);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border(context), width: 0.5),
      ),
      elevation: 0,
      color: AppColors.cardBackground(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Ícone
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFuture ? Icons.calendar_today : Icons.payments,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Informações
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provento.ticker,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _tiposProvento[provento.tipoProvento] ??
                              provento.tipoProvento,
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        _dateFormatter.format(provento.dataPagamento),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      if (isFuture)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Futuro',
                            style: TextStyle(
                              fontSize: 9,
                              color: const Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Valor e ações
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormatter.format(provento.totalRecebido),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _mostrarFormulario(provento),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deletarProvento(provento),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.delete_outline,
                            size: 16, color: AppColors.error),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payments_outlined,
              size: 64,
              color: AppColors.textSecondary(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum provento',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhum resultado para "$_searchQuery"'
                  : 'Toque em + para adicionar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 📦 MODELO PROVENTO
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

  Provento({
    required this.id,
    required this.ticker,
    required this.tipoProvento,
    required this.valorPorCota,
    this.quantidade,
    required this.totalRecebido,
    required this.dataPagamento,
    this.dataCom,
    required this.isFuture,
    this.observacao,
  });

  factory Provento.fromJson(Map<String, dynamic> json) {
    DateTime dataPagamento;
    try {
      dataPagamento = json['data_pagamento'] != null
          ? DateTime.parse(json['data_pagamento'].toString())
          : DateTime.now();
    } catch (e) {
      dataPagamento = DateTime.now();
    }

    DateTime? dataCom;
    try {
      dataCom = json['data_com'] != null
          ? DateTime.parse(json['data_com'].toString())
          : null;
    } catch (e) {
      dataCom = null;
    }

    return Provento(
      id: json['id'].toString(),
      ticker: json['ticker']?.toString() ?? '',
      tipoProvento: json['tipo_provento']?.toString() ?? 'DIVIDENDO',
      valorPorCota: (json['valor_por_cota'] as num?)?.toDouble() ?? 0.0,
      quantidade: (json['quantidade'] as num?)?.toDouble(),
      totalRecebido: (json['total_recebido'] as num?)?.toDouble() ?? 0.0,
      dataPagamento: dataPagamento,
      dataCom: dataCom,
      isFuture: dataPagamento.isAfter(DateTime.now()),
      observacao: json['observacao']?.toString(),
    );
  }
}
