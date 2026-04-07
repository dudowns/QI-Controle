import '../services/logger_service.dart';
// lib/screens/lancamentos_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';
import '../widgets/animated_counter.dart';
import '../widgets/app_modals.dart';

class LancamentosScreen extends StatefulWidget {
  const LancamentosScreen({super.key});

  @override
  State<LancamentosScreen> createState() => _LancamentosScreenState();
}

class _LancamentosScreenState extends State<LancamentosScreen> {
  final DBHelper _dbHelper = DBHelper();

  List<Map<String, dynamic>> _lancamentos = [];
  bool _isLoading = true;

  DateTime _mesSelecionado = DateTime.now();
  String _filtroTipo = 'Todos';
  String _filtroCategoria = 'Todas';

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

  List<Map<String, dynamic>> get _lancamentosFiltrados {
    var filtrados = List<Map<String, dynamic>>.from(_lancamentos);

    filtrados = filtrados.where((l) {
      final data = DateTime.parse(l['data']);
      return data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month;
    }).toList();

    if (_filtroTipo == 'Receitas') {
      filtrados = filtrados.where((l) => l['tipo'] == 'receita').toList();
    } else if (_filtroTipo == 'Despesas') {
      filtrados = filtrados.where((l) => l['tipo'] == 'gasto').toList();
    }

    if (_filtroCategoria != 'Todas') {
      filtrados =
          filtrados.where((l) => l['categoria'] == _filtroCategoria).toList();
    }

    filtrados.sort((a, b) => b['data'].compareTo(a['data']));
    return filtrados;
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _lancamentos = await _dbHelper.getAllLancamentos();
    } catch (e) {
      LoggerService.info('❌ Erro ao carregar lançamentos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
    }
  }

  Future<void> _editarLancamento(Map<String, dynamic> lancamento) async {
    final resultado = await AppModals.mostrarModalLancamento(
      context: context,
      lancamento: lancamento,
    );
    if (resultado != null) {
      await _atualizarLancamento(resultado);
    }
  }

  Future<void> _salvarLancamento(Map<String, dynamic> lancamento) async {
    try {
      await _dbHelper.insertLancamento(lancamento);
      await _carregarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${lancamento['descricao']} adicionado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _atualizarLancamento(Map<String, dynamic> lancamento) async {
    try {
      await _dbHelper.updateLancamento(lancamento);
      await _carregarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✏️ ${lancamento['descricao']} atualizado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _excluirLancamento(int id, String descricao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: const Text('Excluir'),
        content: Text('Excluir "$descricao"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _dbHelper.deleteLancamento(id);
        await _carregarDados();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ $descricao excluído!'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                                icon: const Icon(Icons.chevron_left, size: 18),
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
                                icon: const Icon(Icons.chevron_right, size: 18),
                                onPressed: () => _navegarMes(1),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _adicionarLancamento,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
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
                  const SizedBox(height: 16),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          height: 32,
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.border(context)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: _filtroTipo,
                            isExpanded: false,
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down,
                                size: 18,
                                color: AppColors.textSecondary(context)),
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary(context)),
                            items: _tipos
                                .map((tipo) => DropdownMenuItem(
                                    value: tipo, child: Text(tipo)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _filtroTipo = value!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          height: 32,
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.border(context)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: _filtroCategoria,
                            isExpanded: false,
                            underline: const SizedBox(),
                            icon: Icon(Icons.arrow_drop_down,
                                size: 18,
                                color: AppColors.textSecondary(context)),
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary(context)),
                            items: _categorias.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: cat == 'Todas'
                                            ? Colors.grey
                                            : AppCategories.getColor(cat),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(cat),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _filtroCategoria = value!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _lancamentosFiltrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt,
                                    size: 64, color: AppColors.muted(context)),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhum lançamento',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary(context)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Clique em ADICIONAR para começar',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint(context)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _carregarDados,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              itemCount: _lancamentosFiltrados.length,
                              itemBuilder: (context, index) =>
                                  _buildLancamentoCard(
                                      _lancamentosFiltrados[index]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLancamentoCard(Map<String, dynamic> lancamento) {
    final isReceita = lancamento['tipo'] == 'receita';
    final cor = isReceita ? AppColors.success : AppColors.error;
    final icone = isReceita ? Icons.arrow_upward : Icons.arrow_downward;
    final prefixo = isReceita ? '+' : '-';
    final valor = (lancamento['valor'] as num).toDouble();
    final data = DateTime.parse(lancamento['data']);
    final categoria = lancamento['categoria'] ?? 'Outros';
    final categoriaCor = AppCategories.getColor(categoria);
    final isAuto =
        (lancamento['observacao']?.contains('Pago automaticamente') ?? false);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border(context), width: 1),
      ),
      elevation: 0,
      color: AppColors.cardBackground(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cor.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, color: cor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lancamento['descricao'],
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
                          color: categoriaCor.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: categoriaCor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              categoria,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: categoriaCor,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatador.data(data),
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context)),
                      ),
                      if (isAuto)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule,
                                  size: 8, color: AppColors.info),
                              SizedBox(width: 4),
                              Text(
                                'Automático',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
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
                  duration: const Duration(milliseconds: 600),
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: cor),
                  formatter: (val) => '$prefixo ${Formatador.moeda(val)}',
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _editarLancamento(lancamento),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _excluirLancamento(
                          lancamento['id'], lancamento['descricao']),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha:0.1),
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
}

