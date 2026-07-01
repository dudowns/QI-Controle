// lib/screens/lancamentos.dart - COM ÍCONES POR CATEGORIA
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lancamento_model.dart';
import '../repositories/repositories.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_modals.dart';
import '../services/logger_service.dart';
import '../services/theme_service.dart';

class LancamentosScreen extends StatefulWidget {
  const LancamentosScreen({super.key});

  @override
  State<LancamentosScreen> createState() => _LancamentosScreenState();
}

class _LancamentosScreenState extends State<LancamentosScreen> {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: AppColors.error));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${lancamento['descricao']} adicionado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _atualizarLancamento(Map<String, dynamic> lancamento) async {
    try {
      await _repository.updateLancamentoResult(Lancamento.fromJson(lancamento));
      await _carregarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${lancamento['descricao']} atualizado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _excluirLancamento(int id, String descricao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$descricao excluido!'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: AppColors.error));
        }
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

  // 🔥 ÍCONE POR CATEGORIA
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

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Lançamentos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                          fontSize: 16,
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
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildResumoCard('Receitas', totalReceitas,
                          AppColors.success, Icons.trending_up),
                      const SizedBox(width: 12),
                      _buildResumoCard('Despesas', totalDespesas,
                          AppColors.error, Icons.trending_down),
                      const SizedBox(width: 12),
                      _buildResumoCard(
                          'Saldo',
                          saldo,
                          saldo >= 0 ? AppColors.success : AppColors.error,
                          Icons.account_balance_wallet),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: _buildSearchField()),
                      const SizedBox(width: 8),
                      _buildFilterDropdown(_tipos, _filtroTipo, (value) {
                        setState(() => _filtroTipo = value!);
                        _aplicarFiltros();
                      }, Icons.filter_list),
                      const SizedBox(width: 8),
                      _buildFilterDropdown(_categorias, _filtroCategoria,
                          (value) {
                        setState(() => _filtroCategoria = value!);
                        _aplicarFiltros();
                      }, Icons.category),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredLancamentos.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _carregarDados,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _filteredLancamentos.length,
                            itemBuilder: (context, index) {
                              return FadeInLeft(
                                duration: const Duration(milliseconds: 300),
                                delay: Duration(milliseconds: index * 50),
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

  Widget _buildResumoCard(
      String title, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(title,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary(context))),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedCounter(
              value: value,
              duration: const Duration(milliseconds: 600),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
              formatter: (val) => Formatador.moeda(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _aplicarFiltros();
        },
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
        decoration: InputDecoration(
          hintText: 'Buscar...',
          hintStyle: TextStyle(
              color: AppColors.textSecondary(context).withValues(alpha: 0.5),
              fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              size: 18, color: AppColors.textSecondary(context)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: AppColors.textSecondary(context)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _aplicarFiltros();
                  })
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(List<String> items, String value,
      Function(String?) onChanged, IconData icon) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.2)),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        icon: Icon(icon, size: 18, color: AppColors.textSecondary(context)),
        style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
        dropdownColor: AppColors.surface(context),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Row(
              children: [
                if (item != 'Todos' && item != 'Receitas' && item != 'Despesas')
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppCategories.getColor(item),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (item != 'Todos' && item != 'Receitas' && item != 'Despesas')
                  const SizedBox(width: 6),
                Text(item, style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // 🔥 CARD COM ÍCONE DA CATEGORIA (não a seta + ou -)
  Widget _buildLancamentoCard(Map<String, dynamic> lancamento) {
    final isReceita = lancamento['tipo'] == 'receita';
    final cor = isReceita ? AppColors.success : AppColors.error;
    final prefixo = isReceita ? '+' : '-';
    final valor = (lancamento['valor'] as num).toDouble();
    final data = DateTime.parse(lancamento['data'].toString());
    final categoria = lancamento['categoria'] ?? 'Outros';
    final categoriaCor = _getCategoryColor(categoria);
    final categoriaIcon = _getCategoryIconData(categoria);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: AppColors.border(context).withValues(alpha: 0.3), width: 1),
      ),
      elevation: 0,
      color: AppColors.cardBackground(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 🔥 ÍCONE DA CATEGORIA (ao invés da seta)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoriaCor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(categoriaIcon, size: 22, color: categoriaCor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lancamento['descricao'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoriaCor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          categoria,
                          style: TextStyle(fontSize: 10, color: categoriaCor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        Formatador.diaMes(data),
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context)),
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
                  duration: const Duration(milliseconds: 600),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: cor),
                  formatter: (val) => '$prefixo ${Formatador.moeda(val)}',
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionIcon(
                        Icons.edit_rounded, () => _editarLancamento(lancamento),
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    _buildActionIcon(
                        Icons.delete_outline_rounded,
                        () => _excluirLancamento(
                            lancamento['id'], lancamento['descricao']),
                        color: AppColors.error),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color ?? AppColors.primary),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 64,
              color: AppColors.textSecondary(context).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Nenhum resultado para "$_searchQuery"'
                : 'Nenhum lançamento',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context)),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tente outra busca'
                : 'Toque no + para adicionar',
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}
