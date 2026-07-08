// lib/screens/mobile/lancamentos_mobile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/lancamento_model.dart';
import '../../repositories/repositories.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_categories.dart';
import '../../utils/formatters.dart';
import '../../widgets/animated_counter.dart';
import '../../widgets/app_modals.dart';
import '../../services/logger_service.dart';
import '../../widgets/toast.dart';

class LancamentosMobileScreen extends StatefulWidget {
  const LancamentosMobileScreen({super.key});

  @override
  State<LancamentosMobileScreen> createState() =>
      _LancamentosMobileScreenState();
}

class _LancamentosMobileScreenState extends State<LancamentosMobileScreen> {
  final LancamentoRepository _repository = LancamentoRepository();

  List<Map<String, dynamic>> _lancamentos = [];
  List<Map<String, dynamic>> _filteredLancamentos = [];
  bool _isLoading = true;

  DateTime _mesSelecionado = DateTime.now();
  String _filtroTipo = 'Todos';
  String _filtroCategoria = 'Todas';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

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

  final List<String> _tipos = ['Todos', 'Receitas', 'Despesas'];

  List<String> get _categorias {
    final todas = [...AppCategories.receitas, ...AppCategories.gastos];
    return ['Todas', ...todas.toSet().toList()];
  }

  void _aplicarFiltros() {
    var filtrados = List<Map<String, dynamic>>.from(_lancamentos);

    filtrados = filtrados.where((l) {
      final data = DateTime.parse(l['data'].toString());
      return data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month;
    }).toList();

    if (_filtroTipo == 'Receitas') {
      filtrados = filtrados.where((l) => l['tipo'] == 'receita').toList();
    } else if (_filtroTipo == 'Despesas') {
      filtrados = filtrados.where((l) {
        final tipo = l['tipo']?.toString().toLowerCase() ?? '';
        return tipo == 'gasto' || tipo == 'despesa';
      }).toList();
    }

    if (_filtroCategoria != 'Todas') {
      filtrados =
          filtrados.where((l) => l['categoria'] == _filtroCategoria).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtrados = filtrados.where((l) {
        return l['descricao']?.toString().toLowerCase().contains(query) ==
                true ||
            l['categoria']?.toString().toLowerCase().contains(query) == true;
      }).toList();
    }

    filtrados.sort((a, b) => b['data'].compareTo(a['data']));

    setState(() => _filteredLancamentos = filtrados);
  }

  List<Map<String, dynamic>> get _lancamentosMes {
    return _lancamentos.where((l) {
      try {
        final dataStr = l['data'];
        if (dataStr == null) return false;
        final data = DateTime.parse(dataStr.toString());
        return data.year == _mesSelecionado.year &&
            data.month == _mesSelecionado.month;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  double _calcularTotalPorTipo(String tipo) {
    double total = 0.0;
    for (var lancamento in _lancamentosMes) {
      final tipoLancamento = lancamento['tipo']?.toString().toLowerCase() ?? '';
      final valorRaw = lancamento['valor'];
      double valor = 0.0;
      if (valorRaw != null) {
        if (valorRaw is num) {
          valor = valorRaw.toDouble();
        } else if (valorRaw is String) {
          valor = double.tryParse(valorRaw) ?? 0.0;
        }
      }
      if (tipo == 'receita') {
        if (tipoLancamento == 'receita') {
          total += valor;
        }
      } else {
        if (tipoLancamento == 'gasto' || tipoLancamento == 'despesa') {
          total += valor;
        }
      }
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _lancamentos = await _repository.getAllLancamentos();
      _aplicarFiltros();
    } catch (e) {
      LoggerService.info('Erro ao carregar lancamentos: $e');
      if (mounted) {
        Toast.error(context, 'Erro ao carregar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navegarMes(int delta) {
    setState(() {
      _mesSelecionado =
          DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1);
    });
    _carregarDados();
  }

  Future<void> _adicionarLancamento() async {
    final resultado = await AppModals.mostrarModalLancamento(context: context);
    if (resultado != null) {
      await _salvarLancamento(resultado);
      await _carregarDados();
    }
  }

  Future<void> _editarLancamento(Map<String, dynamic> lancamento) async {
    final resultado = await AppModals.mostrarModalLancamento(
        context: context, lancamento: lancamento);
    if (resultado != null) {
      await _atualizarLancamento(resultado);
      await _carregarDados();
    }
  }

  Future<void> _salvarLancamento(Map<String, dynamic> lancamento) async {
    try {
      await _repository.insertLancamento(lancamento);
      await _carregarDados();
      Toast.success(context, '✅ ${lancamento['descricao']} adicionado!');
    } catch (e) {
      Toast.error(context, 'Erro ao salvar: $e');
    }
  }

  Future<void> _atualizarLancamento(Map<String, dynamic> lancamento) async {
    try {
      await _repository.updateLancamentoResult(Lancamento.fromJson(lancamento));
      await _carregarDados();
      Toast.success(context, '✅ ${lancamento['descricao']} atualizado!');
    } catch (e) {
      Toast.error(context, 'Erro ao atualizar: $e');
    }
  }

  Future<void> _excluirLancamento(int id, String descricao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Excluir',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Excluir "$descricao"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _repository.deleteLancamentoResult(id);
        await _carregarDados();
        Toast.warning(context, '🗑️ $descricao excluido!');
      } catch (e) {
        Toast.error(context, 'Erro ao excluir: $e');
      }
    }
  }

  void _voltar() {
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/main');
      }
    }
  }

  IconData _getCategoryIconData(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'alimentação':
      case 'alimentacao':
        return Icons.restaurant_rounded;
      case 'transporte':
        return Icons.directions_car_rounded;
      case 'moradia':
        return Icons.home_rounded;
      case 'lazer':
        return Icons.movie_rounded;
      case 'saúde':
      case 'saude':
        return Icons.health_and_safety_rounded;
      case 'educação':
      case 'educacao':
        return Icons.school_rounded;
      case 'cartão':
      case 'cartao':
        return Icons.credit_card_rounded;
      case 'investimentos':
        return Icons.trending_up_rounded;
      case 'cuidados pessoais':
        return Icons.person_rounded;
      case 'empréstimo':
      case 'emprestimo':
        return Icons.request_quote_rounded;
      case 'água':
      case 'agua':
        return Icons.water_drop_rounded;
      case 'luz':
        return Icons.flash_on_rounded;
      case 'internet':
        return Icons.wifi_rounded;
      case 'telefone':
        return Icons.phone_android_rounded;
      case 'salário':
      case 'salario':
        return Icons.work_rounded;
      case 'bico ou extra':
        return Icons.attach_money_rounded;
      case 'venda de ativos':
        return Icons.sell_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String categoria) {
    return AppCategories.getColor(categoria);
  }

  @override
  Widget build(BuildContext context) {
    final totalReceitas = _calcularTotalPorTipo('receita');
    final totalDespesas = _calcularTotalPorTipo('gasto');
    final saldo = totalReceitas - totalDespesas;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Lançamentos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary(context)),
            onPressed: _voltar),
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
              onPressed: _adicionarLancamento,
              tooltip: 'Adicionar lançamento',
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
          : Column(
              children: [
                // SELETOR DE MÊS
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left,
                            size: 28, color: AppColors.primary),
                        onPressed: () => _navegarMes(-1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '${_meses[_mesSelecionado.month - 1]} ${_mesSelecionado.year}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right,
                            size: 28, color: AppColors.primary),
                        onPressed: () => _navegarMes(1),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // CARDS DE RESUMO (MOBILE)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildResumoCard(
                          'Receitas', totalReceitas, AppColors.success),
                      const SizedBox(width: 8),
                      _buildResumoCard(
                          'Despesas', totalDespesas, AppColors.error),
                      const SizedBox(width: 8),
                      _buildResumoCard('Saldo', saldo,
                          saldo >= 0 ? AppColors.success : AppColors.error),
                    ],
                  ),
                ),

                // BUSCA E FILTROS
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _buildSearchField(),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Todos', _filtroTipo, () {
                              setState(() => _filtroTipo = 'Todos');
                              _aplicarFiltros();
                            }),
                            _buildFilterChip('Receitas', _filtroTipo, () {
                              setState(() => _filtroTipo = 'Receitas');
                              _aplicarFiltros();
                            }),
                            _buildFilterChip('Despesas', _filtroTipo, () {
                              setState(() => _filtroTipo = 'Despesas');
                              _aplicarFiltros();
                            }),
                            const SizedBox(width: 8),
                            _buildCategoriaFilter(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // LISTA DE LANÇAMENTOS
                Expanded(
                  child: _filteredLancamentos.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _carregarDados,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            itemCount: _filteredLancamentos.length,
                            itemBuilder: (context, index) {
                              return FadeInLeft(
                                duration: const Duration(milliseconds: 250),
                                delay: Duration(milliseconds: index * 30),
                                child: _buildLancamentoCard(
                                    _filteredLancamentos[index]),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumoCard(String title, double value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedCounter(
              value: value,
              duration: const Duration(milliseconds: 500),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              formatter: (val) => Formatador.moeda(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _aplicarFiltros();
        },
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar...',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
            fontSize: 13,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              size: 16, color: isDark ? Colors.grey[400] : Colors.grey[500]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _aplicarFiltros();
                  })
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String current, VoidCallback onTap) {
    final isSelected = current == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriaFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: DropdownButton<String>(
        value: _filtroCategoria,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down,
            size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Colors.white : Colors.black87,
        ),
        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        items: _categorias.map((cat) {
          return DropdownMenuItem(
            value: cat,
            child: Row(
              children: [
                if (cat != 'Todas')
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppCategories.getColor(cat),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (cat != 'Todas') const SizedBox(width: 4),
                Text(
                  cat,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _filtroCategoria = value!);
          _aplicarFiltros();
        },
      ),
    );
  }

  Widget _buildLancamentoCard(Map<String, dynamic> lancamento) {
    final isReceita = lancamento['tipo'] == 'receita';
    final cor = isReceita ? AppColors.success : AppColors.error;
    final prefixo = isReceita ? '+' : '-';
    final valor = (lancamento['valor'] as num).toDouble();
    final data = DateTime.parse(lancamento['data'].toString());
    final categoria = lancamento['categoria'] ?? 'Outros';
    final categoriaCor = _getCategoryColor(categoria);
    final categoriaIcon = _getCategoryIconData(categoria);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: categoriaCor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(categoriaIcon, size: 18, color: categoriaCor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lancamento['descricao'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: categoriaCor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoria,
                          style: TextStyle(
                            fontSize: 9,
                            color: categoriaCor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Formatador.diaMes(data),
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
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
                AnimatedCounter(
                  value: valor,
                  duration: const Duration(milliseconds: 400),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
                  formatter: (val) => '$prefixo ${Formatador.moeda(val)}',
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildActionIcon(
                      Icons.edit_rounded,
                      () => _editarLancamento(lancamento),
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    _buildActionIcon(
                      Icons.delete_outline_rounded,
                      () => _excluirLancamento(
                          lancamento['id'], lancamento['descricao']),
                      color: AppColors.error,
                      size: 14,
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

  Widget _buildActionIcon(IconData icon, VoidCallback onTap,
      {Color? color, double size = 16}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: size, color: color ?? AppColors.primary),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 48, color: isDark ? Colors.grey[600] : Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'Nenhum resultado para "$_searchQuery"'
                : 'Nenhum lançamento',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tente outra busca'
                : 'Toque no + para adicionar',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
