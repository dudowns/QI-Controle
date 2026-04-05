// lib/screens/proventos.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class ProventosScreen extends StatefulWidget {
  const ProventosScreen({super.key});

  @override
  State<ProventosScreen> createState() => _ProventosScreenState();
}

class _ProventosScreenState extends State<ProventosScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _proventos = [];
  List<String> _tickersDisponiveis = [];
  bool _carregando = true;
  String _filtroPeriodo = '12M';
  final List<String> _periodos = ['1M', '3M', '6M', '12M', 'TODOS'];

  final Map<String, double> _proventosPorMes = {};
  final Map<String, double> _proventosPorAtivo = {};
  double _totalPeriodo = 0;
  double _mediaMensal = 0;
  double _projetadoProximoMes = 0;

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não logado');
    return user.id;
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _carregarTickers();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final response = await _supabase
          .from('proventos')
          .select()
          .eq('user_id', _userId)
          .order('data_pagamento', ascending: false);

      _proventos = List<Map<String, dynamic>>.from(response);
      _calcularEstatisticas();
    } catch (e) {
      debugPrint('❌ Erro ao carregar proventos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _carregarTickers() async {
    try {
      final response = await _supabase
          .from('investimentos')
          .select('ticker')
          .eq('user_id', _userId);

      _tickersDisponiveis =
          response.map((inv) => inv['ticker'] as String).toSet().toList();

      if (_tickersDisponiveis.isEmpty) {
        _tickersDisponiveis = ['PETR4', 'VALE3', 'ITUB4', 'BBDC4', 'ABEV3'];
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar tickers: $e');
      _tickersDisponiveis = ['PETR4', 'VALE3', 'ITUB4', 'BBDC4', 'ABEV3'];
    }
  }

  void _calcularEstatisticas() {
    _proventosPorMes.clear();
    _proventosPorAtivo.clear();
    _totalPeriodo = 0;

    final agora = DateTime.now();
    DateTime dataLimite;

    switch (_filtroPeriodo) {
      case '1M':
        dataLimite = DateTime(agora.year, agora.month - 1, agora.day);
        break;
      case '3M':
        dataLimite = DateTime(agora.year, agora.month - 3, agora.day);
        break;
      case '6M':
        dataLimite = DateTime(agora.year, agora.month - 6, agora.day);
        break;
      case '12M':
        dataLimite = DateTime(agora.year - 1, agora.month, agora.day);
        break;
      default:
        dataLimite = DateTime(2000);
    }

    for (var p in _proventos) {
      final dataPagamento = DateTime.parse(p['data_pagamento']);
      if (dataPagamento.isAfter(dataLimite) || _filtroPeriodo == 'TODOS') {
        final total = (p['total_recebido'] as num).toDouble();
        _totalPeriodo += total;

        final chaveMes = _formatarMes(dataPagamento);
        _proventosPorMes[chaveMes] = (_proventosPorMes[chaveMes] ?? 0) + total;

        _proventosPorAtivo[p['ticker']] =
            (_proventosPorAtivo[p['ticker']] ?? 0) + total;
      }
    }

    _mediaMensal =
        _proventosPorMes.isEmpty ? 0 : _totalPeriodo / _proventosPorMes.length;

    final tresMesesAtras = DateTime(agora.year, agora.month - 3, agora.day);
    double somaUltimos3 = 0;
    int count = 0;

    for (var p in _proventos) {
      final dataPagamento = DateTime.parse(p['data_pagamento']);
      if (dataPagamento.isAfter(tresMesesAtras)) {
        somaUltimos3 += (p['total_recebido'] as num).toDouble();
        count++;
      }
    }

    _projetadoProximoMes = count > 0 ? somaUltimos3 / count : 0;
  }

  String _formatarMes(DateTime data) {
    const meses = [
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
    return '${meses[data.month - 1]}/${data.year.toString().substring(2)}';
  }

  List<PieChartSectionData> _getGraficoProventos() {
    final List<PieChartSectionData> sections = [];
    final cores = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.brown
    ];

    final ativosOrdenados = _proventosPorAtivo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int corIndex = 0;
    for (var entry in ativosOrdenados.take(6)) {
      final percentual = (entry.value / _totalPeriodo) * 100;
      sections.add(PieChartSectionData(
        value: entry.value,
        color: cores[corIndex % cores.length],
        title: percentual > 3 ? '${percentual.toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 70,
      ));
      corIndex++;
    }

    if (ativosOrdenados.length > 6) {
      double outros = 0;
      for (int i = 6; i < ativosOrdenados.length; i++) {
        outros += ativosOrdenados[i].value;
      }
      if (outros > 0) {
        sections.add(PieChartSectionData(
          value: outros,
          color: Colors.grey,
          title: 'Outros',
          titleStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          radius: 70,
        ));
      }
    }

    return sections;
  }

  Future<void> _adicionarProvento() async {
    String? tickerSelecionado =
        _tickersDisponiveis.isNotEmpty ? _tickersDisponiveis.first : null;
    final valorCtrl = TextEditingController();
    final quantidadeCtrl = TextEditingController();
    DateTime dataPagamento = DateTime.now();
    String tipoProvento = 'Dividendo';

    if (_tickersDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Primeiro adicione um investimento'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('Adicionar Provento',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: tickerSelecionado,
                          decoration: const InputDecoration(
                              labelText: 'Ativo', border: OutlineInputBorder()),
                          items: _tickersDisponiveis.map((ticker) {
                            return DropdownMenuItem(
                                value: ticker, child: Text(ticker));
                          }).toList(),
                          onChanged: (value) =>
                              setStateModal(() => tickerSelecionado = value),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: tipoProvento,
                          decoration: const InputDecoration(
                              labelText: 'Tipo', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(
                                value: 'Dividendo', child: Text('Dividendo')),
                            DropdownMenuItem(value: 'JCP', child: Text('JCP')),
                            DropdownMenuItem(
                                value: 'Rendimento', child: Text('Rendimento')),
                          ],
                          onChanged: (value) =>
                              setStateModal(() => tipoProvento = value!),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: valorCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Valor por cota (R\$)',
                              hintText: '0,00',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantidadeCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Quantidade',
                              hintText: '1',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dataPagamento,
                              firstDate: DateTime(2020),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null)
                              setStateModal(() => dataPagamento = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 12),
                                Text(Formatador.data(dataPagamento)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (tickerSelecionado == null ||
                                  valorCtrl.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Preencha todos os campos!')),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              final valor = double.parse(
                                  valorCtrl.text.replaceAll(',', '.'));
                              final quantidade = quantidadeCtrl.text.isNotEmpty
                                  ? double.parse(quantidadeCtrl.text)
                                  : 1;
                              final total = valor * quantidade;
                              try {
                                await _supabase.from('proventos').insert({
                                  'ticker': tickerSelecionado,
                                  'tipo_provento': tipoProvento,
                                  'valor_por_cota': valor,
                                  'quantidade': quantidade,
                                  'data_pagamento':
                                      dataPagamento.toIso8601String(),
                                  'total_recebido': total,
                                  'user_id': _userId,
                                });
                                await _carregarDados();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('✅ Provento adicionado!'),
                                        backgroundColor: AppColors.success),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Erro: $e'),
                                        backgroundColor: AppColors.error),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary),
                            child: const Text('SALVAR',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editarProvento(Map<String, dynamic> provento) async {
    final valorCtrl = TextEditingController(
        text: provento['valor_por_cota'].toString().replaceAll('.', ','));
    final quantidadeCtrl =
        TextEditingController(text: provento['quantidade'].toString());
    DateTime dataPagamento = DateTime.parse(provento['data_pagamento']);
    String tipoProvento = provento['tipo_provento'] ?? 'Dividendo';
    final id = provento['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('Editar Provento',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: tipoProvento,
                          decoration: const InputDecoration(
                              labelText: 'Tipo', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(
                                value: 'Dividendo', child: Text('Dividendo')),
                            DropdownMenuItem(value: 'JCP', child: Text('JCP')),
                            DropdownMenuItem(
                                value: 'Rendimento', child: Text('Rendimento')),
                          ],
                          onChanged: (value) =>
                              setStateModal(() => tipoProvento = value!),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: valorCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Valor por cota (R\$)',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantidadeCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Quantidade',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dataPagamento,
                              firstDate: DateTime(2020),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null)
                              setStateModal(() => dataPagamento = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 12),
                                Text(Formatador.data(dataPagamento)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Excluir'),
                                      content: Text(
                                          'Excluir provento de ${provento['ticker']}?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Excluir',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    Navigator.pop(context);
                                    try {
                                      await _supabase
                                          .from('proventos')
                                          .delete()
                                          .eq('id', id);
                                      await _carregarDados();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  '🗑️ Provento excluído!'),
                                              backgroundColor: Colors.orange),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('Erro: $e'),
                                              backgroundColor: AppColors.error),
                                        );
                                      }
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('EXCLUIR'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final valor = double.parse(
                                      valorCtrl.text.replaceAll(',', '.'));
                                  final quantidade =
                                      double.parse(quantidadeCtrl.text);
                                  final total = valor * quantidade;
                                  try {
                                    await _supabase.from('proventos').update({
                                      'tipo_provento': tipoProvento,
                                      'valor_por_cota': valor,
                                      'quantidade': quantidade,
                                      'data_pagamento':
                                          dataPagamento.toIso8601String(),
                                      'total_recebido': total,
                                    }).eq('id', id);
                                    await _carregarDados();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('✅ Provento atualizado!'),
                                            backgroundColor: AppColors.success),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text('Erro: $e'),
                                            backgroundColor: AppColors.error),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary),
                                child: const Text('ATUALIZAR',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _getGraficoProventos();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Período:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: _periodos.map((periodo) {
                            final isSelected = _filtroPeriodo == periodo;
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: FilterChip(
                                  label: Text(periodo),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _filtroPeriodo = periodo;
                                      _calcularEstatisticas();
                                    });
                                  },
                                  selectedColor:
                                      AppColors.primary.withOpacity(0.1),
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary(context),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildResumoCard('Total', _totalPeriodo,
                              Icons.summarize, AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildResumoCard('Média', _mediaMensal,
                              Icons.calculate, Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildResumoCard(
                              'Projetado',
                              _projetadoProximoMes,
                              Icons.trending_up,
                              Colors.orange)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (sections.isNotEmpty && _totalPeriodo > 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.border(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💰 Distribuição por Ativo',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: PieChart(PieChartData(
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 40,
                                    sections: sections,
                                  )),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children:
                                      _proventosPorAtivo.entries.map((entry) {
                                    final percentual =
                                        (entry.value / _totalPeriodo) * 100;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface(context)
                                            .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppColors.border(context)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                  color: AppColors.primary,
                                                  shape: BoxShape.circle)),
                                          const SizedBox(width: 4),
                                          Text(entry.key,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary(
                                                      context))),
                                          const SizedBox(width: 4),
                                          Text(
                                              '${percentual.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppColors.textSecondary(
                                                          context))),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (_proventos.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.attach_money,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text('Nenhum provento registrado',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600])),
                                  const SizedBox(height: 8),
                                  Text('Toque no botão + para adicionar',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500])),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._proventos.map((p) => _buildProventoCard(p)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: _adicionarProvento,
      ),
    );
  }

  Widget _buildResumoCard(
      String label, double valor, IconData icone, Color cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: AppColors.textSecondary(context)))
          ]),
          const SizedBox(height: 8),
          Text(Formatador.moedaCompacta(valor),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
        ],
      ),
    );
  }

  Widget _buildProventoCard(Map<String, dynamic> p) {
    final dataPagamento = DateTime.parse(p['data_pagamento']);
    final hoje = DateTime.now();
    final isFuturo = dataPagamento.isAfter(hoje);
    final diasParaPagamento = dataPagamento.difference(hoje).inDays;

    Color statusColor;
    String statusText;

    if (isFuturo) {
      if (diasParaPagamento <= 7) {
        statusColor = Colors.orange;
        statusText = '⚠️ Próximo';
      } else {
        statusColor = AppColors.primary;
        statusText = '⏳ Futuro';
      }
    } else {
      statusColor = Colors.green;
      statusText = '✅ Recebido';
    }

    return GestureDetector(
      onTap: () => _editarProvento(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.monetization_on, color: statusColor)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(p['ticker'],
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context))),
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(statusText,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 4),
                      Text(p['tipo_provento'] ?? 'Dividendo',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Formatador.moeda(p['total_recebido']),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                    const SizedBox(height: 4),
                    Text(
                        '${(p['quantidade'] as num).toDouble().toStringAsFixed(0)} cotas',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.calendar_today,
                      size: 12, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 4),
                  Text('Pagamento: ${Formatador.data(dataPagamento)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context)))
                ]),
                if (p['data_com'] != null)
                  Row(children: [
                    Icon(Icons.event,
                        size: 12, color: AppColors.textSecondary(context)),
                    const SizedBox(width: 4),
                    Text(
                        'COM: ${Formatador.data(DateTime.parse(p['data_com']))}',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context)))
                  ]),
                Icon(Icons.edit, size: 18, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
