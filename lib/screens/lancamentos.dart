// lib/screens/lancamentos.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../repositories/lancamento_repository.dart';
import '../models/lancamento_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_categories.dart';
import '../widgets/primary_card.dart';
import '../widgets/modern_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/animated_counter.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/formatters.dart';
import '../services/performance_service.dart';
import '../widgets/nova_transacao_modal.dart';
import '../widgets/editar_transacao_modal.dart'; // 🔥 IMPORT DO MODAL!

enum Ordenacao { dataDesc, dataAsc, valorDesc, valorAsc }

class LancamentosScreen extends StatefulWidget {
  const LancamentosScreen({super.key});

  @override
  State<LancamentosScreen> createState() => _LancamentosScreenState();
}

class _LancamentosScreenState extends State<LancamentosScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final LancamentoRepository _lancamentoRepo = LancamentoRepository();

  List<Map<String, dynamic>> lancamentos = [];
  List<Map<String, dynamic>>? _lancamentosFiltradosCache;

  Map<String, dynamic>? _resumoMes;

  bool carregando = true;
  bool _primeiraCarga = true;
  bool _temMaisItens = true;
  int _paginaAtual = 1;
  final ScrollController _scrollController = ScrollController();

  late AnimationController _animationController;

  String filtroTipo = 'Todos';
  String filtroCategoria = 'Todas';
  DateTime? dataInicio;
  DateTime? dataFim;
  Ordenacao _ordenacaoAtual = Ordenacao.dataDesc;

  final List<String> tipos = const ['Todos', 'Receita', 'Gasto'];

  final List<String> categorias = [
    'Todas',
    ...AppCategories.gastos,
    ...AppCategories.receitas,
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _carregarLancamentos();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _carregarMaisLancamentos();
    }
  }

  Future<void> _carregarLancamentos() async {
    if (!mounted) return;

    PerformanceService.start('carregarLancamentos');

    setState(() {
      carregando = true;
      _paginaAtual = 1;
    });

    try {
      final novosLancamentos = await _lancamentoRepo.getAllLancamentos();
      lancamentos = [...novosLancamentos];
      _lancamentosFiltradosCache = null;
      _temMaisItens = lancamentos.length >= 20;

      await _carregarResumoMes();

      PerformanceService.stop('carregarLancamentos');
    } catch (e) {
      _mostrarErro('Erro ao carregar lançamentos: $e');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
          _primeiraCarga = false;
        });
      }
    }
  }

  Future<void> _carregarResumoMes() async {
    try {
      _resumoMes = await _lancamentoRepo.getResumoDoMes(DateTime.now());
    } catch (e) {
      debugPrint('❌ Erro ao carregar resumo do mês: $e');
    }
  }

  Future<void> _carregarMaisLancamentos() async {
    if (!_temMaisItens || carregando || !mounted) return;

    try {
      final maisLancamentos = await _lancamentoRepo.getLancamentosPaginados(
        pagina: _paginaAtual + 1,
        tipo: filtroTipo != 'Todos' ? filtroTipo : null,
        categoria: filtroCategoria != 'Todas' ? filtroCategoria : null,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

      if (mounted) {
        setState(() {
          lancamentos = [...lancamentos, ...maisLancamentos];
          _paginaAtual++;
          _temMaisItens = maisLancamentos.length >= 20;
          _lancamentosFiltradosCache = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _mostrarErro('Erro ao carregar mais lançamentos: $e');
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Map<String, dynamic>> get _lancamentosFiltrados {
    if (_lancamentosFiltradosCache != null) {
      return _lancamentosFiltradosCache!;
    }

    final filtrados = lancamentos.where((l) {
      if (filtroTipo != 'Todos') {
        final tipoItem = l['tipo']?.toString().toLowerCase() ?? '';
        final tipoFiltro = filtroTipo.toLowerCase();

        if (tipoFiltro == 'receita' &&
            !(tipoItem == 'receita' || tipoItem == 'receitas')) {
          return false;
        }
        if (tipoFiltro == 'gasto' &&
            !(tipoItem == 'gasto' ||
                tipoItem == 'gastos' ||
                tipoItem == 'despesa')) {
          return false;
        }
      }

      if (filtroCategoria != 'Todas') {
        if (l['categoria'] != filtroCategoria) return false;
      }

      if (dataInicio != null) {
        try {
          final data = DateTime.parse(l['data']);
          if (data.isBefore(dataInicio!)) return false;
        } catch (_) {}
      }

      if (dataFim != null) {
        try {
          final data = DateTime.parse(l['data']);
          if (data.isAfter(dataFim!)) return false;
        } catch (_) {}
      }

      return true;
    }).toList();

    switch (_ordenacaoAtual) {
      case Ordenacao.dataDesc:
        filtrados.sort((a, b) => b['data'].compareTo(a['data']));
        break;
      case Ordenacao.dataAsc:
        filtrados.sort((a, b) => a['data'].compareTo(b['data']));
        break;
      case Ordenacao.valorDesc:
        filtrados.sort((a, b) => (b['valor'] ?? 0).compareTo(a['valor'] ?? 0));
        break;
      case Ordenacao.valorAsc:
        filtrados.sort((a, b) => (a['valor'] ?? 0).compareTo(b['valor'] ?? 0));
        break;
    }

    _lancamentosFiltradosCache = filtrados;
    return filtrados;
  }

  double get _totalReceitas {
    return _lancamentosFiltrados.where((l) {
      final tipo = l['tipo']?.toString().toLowerCase();
      return tipo == 'receita' || tipo == 'receitas';
    }).fold(0, (sum, l) => sum + (l['valor'] ?? 0));
  }

  double get _totalDespesas {
    return _lancamentosFiltrados.where((l) {
      final tipo = l['tipo']?.toString().toLowerCase();
      return tipo == 'gasto' || tipo == 'gastos' || tipo == 'despesa';
    }).fold(0, (sum, l) => sum + (l['valor'] ?? 0));
  }

  double get _saldo => _totalReceitas - _totalDespesas;

  void _limparFiltros() {
    setState(() {
      filtroTipo = 'Todos';
      filtroCategoria = 'Todas';
      dataInicio = null;
      dataFim = null;
      _ordenacaoAtual = Ordenacao.dataDesc;
      _lancamentosFiltradosCache = null;
    });
  }

  void _aplicarFiltros() {
    setState(() {
      _lancamentosFiltradosCache = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        toolbarHeight: 50,
        title: const Text(
          'Gastos',
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            onPressed: _mostrarOpcoesOrdenacao,
            tooltip: 'Ordenar',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, size: 20),
            onPressed: _mostrarFiltros,
            tooltip: 'Filtrar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _carregarLancamentos,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white, size: 24),
        onPressed: () {
          NovaTransacaoModal.show(
            context: context,
            onSalvo: () {
              _carregarLancamentos();
            },
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_primeiraCarga) {
      return const _LancamentosSkeleton();
    }

    if (carregando && lancamentos.isEmpty) {
      return const LoadingIndicator(message: 'Carregando lançamentos...');
    }

    return Column(
      children: [
        _buildResumoCardCompacto(),
        if (_filtrosAtivos) _buildFiltrosIndicador(),
        Expanded(
          child: lancamentos.isEmpty
              ? _buildEmptyState()
              : _lancamentosFiltrados.isEmpty
                  ? _buildSemResultados()
                  : _buildLista(),
        ),
      ],
    );
  }

  Widget _buildResumoCardCompacto() {
    final receitas = _resumoMes?['receitas'] ?? _totalReceitas;
    final despesas = _resumoMes?['despesas'] ?? _totalDespesas;
    final saldo = _resumoMes?['saldo'] ?? _saldo;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  AnimatedCounter(
                    value: saldo,
                    formatter: Formatador.moeda,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  Formatador.mesAno(DateTime.now()),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildResumoItemCompacto(
                  'Receitas',
                  receitas,
                  Icons.arrow_upward,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildResumoItemCompacto(
                  'Despesas',
                  despesas,
                  Icons.arrow_downward,
                  AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoItemCompacto(
      String titulo, double valor, IconData icone, Color cor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              AnimatedCounter(
                value: valor,
                formatter: Formatador.moeda,
                style: TextStyle(
                  color: cor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosIndicador() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _textoFiltrosAtivos,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _limparFiltros,
            icon: const Icon(Icons.clear, size: 14),
            label: const Text('Limpar', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _lancamentosFiltrados.length + (_temMaisItens ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _lancamentosFiltrados.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final item = _lancamentosFiltrados[index];
        return _LancamentoCardCompacto(
          item: item,
          onRefresh: _carregarLancamentos,
        );
      },
    );
  }

  bool get _filtrosAtivos {
    return filtroTipo != 'Todos' ||
        filtroCategoria != 'Todas' ||
        dataInicio != null ||
        dataFim != null ||
        _ordenacaoAtual != Ordenacao.dataDesc;
  }

  String get _textoFiltrosAtivos {
    List<String> filtros = [];

    if (filtroTipo != 'Todos') filtros.add('Tipo: $filtroTipo');
    if (filtroCategoria != 'Todas') filtros.add('Categoria: $filtroCategoria');
    if (dataInicio != null) {
      filtros.add('De: ${DateFormat('dd/MM').format(dataInicio!)}');
    }
    if (dataFim != null) {
      filtros.add('Até: ${DateFormat('dd/MM').format(dataFim!)}');
    }

    switch (_ordenacaoAtual) {
      case Ordenacao.dataDesc:
        filtros.add('Ordenado por: Data');
        break;
      case Ordenacao.dataAsc:
        filtros.add('Ordenado por: Data (antigo)');
        break;
      case Ordenacao.valorDesc:
        filtros.add('Ordenado por: Maior valor');
        break;
      case Ordenacao.valorAsc:
        filtros.add('Ordenado por: Menor valor');
        break;
    }

    return filtros.join(' • ');
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.receipt,
      message: 'Nenhum lançamento cadastrado',
      buttonText: 'Adicionar lançamento',
      onButtonPressed: () {
        NovaTransacaoModal.show(
          context: context,
          onSalvo: () {
            _carregarLancamentos();
          },
        );
      },
    );
  }

  Widget _buildSemResultados() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.filter_alt, size: 48),
          const SizedBox(height: 12),
          Text(
            'Nenhum resultado com os filtros atuais',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            text: 'Limpar filtros',
            icon: Icons.clear,
            onPressed: _limparFiltros,
          ),
        ],
      ),
    );
  }

  void _mostrarOpcoesOrdenacao() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ordenar por',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildOrdenacaoItem(
                'Data (recente)',
                Ordenacao.dataDesc,
                Icons.calendar_today,
              ),
              _buildOrdenacaoItem(
                'Data (antigo)',
                Ordenacao.dataAsc,
                Icons.calendar_today,
              ),
              _buildOrdenacaoItem(
                'Maior valor',
                Ordenacao.valorDesc,
                Icons.trending_up,
              ),
              _buildOrdenacaoItem(
                'Menor valor',
                Ordenacao.valorAsc,
                Icons.trending_down,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdenacaoItem(String titulo, Ordenacao valor, IconData icone) {
    return ListTile(
      leading: Icon(
        icone,
        size: 20,
        color: _ordenacaoAtual == valor ? AppColors.primary : Colors.grey,
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 14,
          color: _ordenacaoAtual == valor
              ? AppColors.primary
              : AppColors.textPrimary(context),
          fontWeight:
              _ordenacaoAtual == valor ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: _ordenacaoAtual == valor
          ? const Icon(Icons.check, color: AppColors.primary, size: 18)
          : null,
      onTap: () {
        setState(() {
          _ordenacaoAtual = valor;
          _lancamentosFiltradosCache = null;
        });
        Navigator.pop(context);
      },
    );
  }

  void _mostrarFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: tipos.map((tipo) {
                        return FilterChip(
                          label:
                              Text(tipo, style: const TextStyle(fontSize: 12)),
                          selected: filtroTipo == tipo,
                          onSelected: (_) {
                            setStateModal(() {
                              filtroTipo = tipo;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Categoria',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: categorias.map((categoria) {
                        return FilterChip(
                          label: Text(categoria,
                              style: const TextStyle(fontSize: 11)),
                          selected: filtroCategoria == categoria,
                          onSelected: (_) {
                            setStateModal(() {
                              filtroCategoria = categoria;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Período',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDataPickerCompacto(
                            'Início',
                            dataInicio,
                            (date) => setStateModal(() => dataInicio = date),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDataPickerCompacto(
                            'Fim',
                            dataFim,
                            (date) => setStateModal(() => dataFim = date),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setStateModal(() {
                                filtroTipo = 'Todos';
                                filtroCategoria = 'Todas';
                                dataInicio = null;
                                dataFim = null;
                              });
                            },
                            child: const Text('Limpar',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GradientButton(
                            text: 'Aplicar',
                            onPressed: () {
                              _aplicarFiltros();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDataPickerCompacto(
      String label, DateTime? data, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: data ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('pt', 'BR'),
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          border: Border.all(color: AppColors.border(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                data == null ? label : DateFormat('dd/MM').format(data),
                style: TextStyle(
                  fontSize: 12,
                  color: data == null
                      ? AppColors.textHint(context)
                      : AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Card de lançamento compacto - AGORA COM MODAL!
class _LancamentoCardCompacto extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;

  const _LancamentoCardCompacto({
    required this.item,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final tipoLower = item['tipo']?.toString().toLowerCase() ?? '';
    final isReceita = tipoLower == 'receita' || tipoLower == 'receitas';
    final cor = isReceita ? AppColors.success : AppColors.error;
    final icone = isReceita ? Icons.arrow_upward : Icons.arrow_downward;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 8),
      child: ModernCard(
        onTap: () async {
          // ✅ AGORA USA O MODAL DE EDIÇÃO!
          await EditarTransacaoModal.show(
            context: context,
            lancamento: item,
            onAtualizado: () {
              onRefresh.call();
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, color: cor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['descricao'] ?? 'Sem descrição',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: cor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['categoria'] ?? 'Outros',
                            style: TextStyle(
                              fontSize: 9,
                              color: cor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          Formatador.data(DateTime.parse(item['data'])),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedCounter(
                value: item['valor']?.toDouble() ?? 0,
                formatter: Formatador.moeda,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LancamentosSkeleton extends StatelessWidget {
  const _LancamentosSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonLoader(
                    child: Container(
                      width: 80,
                      height: 30,
                      color: Colors.white,
                    ),
                  ),
                  SkeletonLoader(
                    child: Container(
                      width: 60,
                      height: 24,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SkeletonLoader(
                      child: Container(
                        height: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkeletonLoader(
                      child: Container(
                        height: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SkeletonLoader(
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
