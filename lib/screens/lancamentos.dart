// lib/screens/lancamentos.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/lancamento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class LancamentosScreen extends StatefulWidget {
  const LancamentosScreen({super.key});

  @override
  State<LancamentosScreen> createState() => _LancamentosScreenState();
}

class _LancamentosScreenState extends State<LancamentosScreen> {
  late final SupabaseService _supabaseService;

  List<Lancamento> _lancamentos = [];
  bool _isLoading = true;

  DateTime _mesSelecionado = DateTime.now();
  String _filtroTipo = 'Todos';
  String _filtroCategoria = 'Todas';

  double _totalReceitas = 0;
  double _totalDespesas = 0;
  double _saldo = 0;

  List<String> get _categorias {
    final todas = [..._categoriasReceitas, ..._categoriasDespesas];
    return ['Todas', ...todas.toSet().toList()];
  }

  final List<String> _categoriasReceitas = [
    'Salário',
    'Bico ou Extra',
    'Venda de Ativos',
    'Outros'
  ];

  final List<String> _categoriasDespesas = [
    'Transporte',
    'Alimentação',
    'Moradia',
    'Lazer',
    'Saúde',
    'Educação',
    'Cartão',
    'Investimentos',
    'Cuidados Pessoais',
    'Empréstimo',
    'Água',
    'Luz',
    'Internet',
    'Telefone',
    'IPVA',
    'IPTU',
    'Cartão de Crédito',
    'Outros'
  ];

  List<String> get _tipos {
    return ['Todos', 'Receitas', 'Despesas'];
  }

  List<Lancamento> get _lancamentosFiltrados {
    var filtrados = List<Lancamento>.from(_lancamentos);

    filtrados = filtrados
        .where((l) =>
            l.data.year == _mesSelecionado.year &&
            l.data.month == _mesSelecionado.month)
        .toList();

    if (_filtroTipo == 'Receitas') {
      filtrados =
          filtrados.where((l) => l.tipo == TipoLancamento.receita).toList();
    } else if (_filtroTipo == 'Despesas') {
      filtrados =
          filtrados.where((l) => l.tipo == TipoLancamento.gasto).toList();
    }

    if (_filtroCategoria != 'Todas') {
      filtrados =
          filtrados.where((l) => l.categoria == _filtroCategoria).toList();
    }

    filtrados.sort((a, b) => b.data.compareTo(a.data));
    return filtrados;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _supabaseService = Provider.of<SupabaseService>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      _lancamentos = await _supabaseService.getLancamentos();
      _calcularTotais();
    } catch (e) {
      debugPrint('Erro ao carregar lançamentos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calcularTotais() {
    double receitas = 0;
    double despesas = 0;

    for (var l in _lancamentosFiltrados) {
      if (l.tipo == TipoLancamento.receita) {
        receitas += l.valor;
      } else {
        despesas += l.valor;
      }
    }

    _totalReceitas = receitas;
    _totalDespesas = despesas;
    _saldo = receitas - despesas;
  }

  void _navegarMes(int delta) {
    setState(() {
      _mesSelecionado =
          DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1);
    });
    _carregarDados();
  }

  Future<void> _adicionarLancamento() async {
    final descricaoCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final observacaoCtrl = TextEditingController();
    String tipo = 'gasto';
    String categoria = 'Outros';
    DateTime data = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
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
                      const Text('Novo Lançamento',
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
                        Row(
                          children: [
                            Expanded(
                                child: _buildTipoBotao(
                                    '💰 Receita',
                                    'receita',
                                    Colors.green,
                                    tipo,
                                    (v) => setStateModal(() => tipo = v))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTipoBotao(
                                    '💸 Despesa',
                                    'gasto',
                                    Colors.red,
                                    tipo,
                                    (v) => setStateModal(() => tipo = v))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: descricaoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Descrição',
                              hintText: 'Ex: Salário, Mercado...',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: valorCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Valor (R\$)',
                              hintText: '0,00',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: categoria,
                          items: (tipo == 'receita'
                                  ? _categoriasReceitas
                                  : _categoriasDespesas)
                              .map((cat) {
                            return DropdownMenuItem(
                                value: cat, child: Text(cat));
                          }).toList(),
                          onChanged: (value) =>
                              setStateModal(() => categoria = value!),
                          decoration: const InputDecoration(
                              labelText: 'Categoria',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: data,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setStateModal(() => data = picked);
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
                                Text(Formatador.data(data)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: observacaoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Observação (opcional)',
                              border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (descricaoCtrl.text.isEmpty ||
                                  valorCtrl.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Preencha descrição e valor!')),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              final novoLancamento = Lancamento(
                                descricao: descricaoCtrl.text,
                                tipo: tipo == 'receita'
                                    ? TipoLancamento.receita
                                    : TipoLancamento.gasto,
                                categoria: categoria,
                                valor: double.parse(
                                    valorCtrl.text.replaceAll(',', '.')),
                                data: data,
                                observacao: observacaoCtrl.text.isNotEmpty
                                    ? observacaoCtrl.text
                                    : null,
                              );
                              try {
                                await _supabaseService
                                    .addLancamento(novoLancamento);
                                await _carregarDados();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('✅ Lançamento adicionado!'),
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

  Widget _buildTipoBotao(String label, String value, Color cor,
      String tipoAtual, Function(String) onTap) {
    final isSelected = tipoAtual == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? cor : Colors.grey[300]!,
              width: isSelected ? 2 : 1),
        ),
        child: Center(
            child: Text(label,
                style: TextStyle(color: isSelected ? cor : Colors.grey[600]))),
      ),
    );
  }

  Future<void> _editarLancamento(Lancamento lancamento) async {
    final descricaoCtrl = TextEditingController(text: lancamento.descricao);
    final valorCtrl = TextEditingController(
        text: lancamento.valor.toString().replaceAll('.', ','));
    final observacaoCtrl =
        TextEditingController(text: lancamento.observacao ?? '');
    String tipo =
        lancamento.tipo == TipoLancamento.receita ? 'receita' : 'gasto';
    String categoria = lancamento.categoria;
    DateTime data = lancamento.data;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
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
                      const Text('Editar Lançamento',
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
                        Row(
                          children: [
                            Expanded(
                                child: _buildTipoBotao(
                                    '💰 Receita',
                                    'receita',
                                    Colors.green,
                                    tipo,
                                    (v) => setStateModal(() => tipo = v))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTipoBotao(
                                    '💸 Despesa',
                                    'gasto',
                                    Colors.red,
                                    tipo,
                                    (v) => setStateModal(() => tipo = v))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                            controller: descricaoCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Descrição',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        TextField(
                            controller: valorCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Valor (R\$)',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: categoria,
                          items: (tipo == 'receita'
                                  ? _categoriasReceitas
                                  : _categoriasDespesas)
                              .map((cat) {
                            return DropdownMenuItem(
                                value: cat, child: Text(cat));
                          }).toList(),
                          onChanged: (value) =>
                              setStateModal(() => categoria = value!),
                          decoration: const InputDecoration(
                              labelText: 'Categoria',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: data,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setStateModal(() => data = picked);
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
                                Text(Formatador.data(data)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                            controller: observacaoCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Observação (opcional)',
                                border: OutlineInputBorder()),
                            maxLines: 2),
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
                                          'Excluir "${lancamento.descricao}"?'),
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
                                      await _supabaseService
                                          .deleteLancamento(lancamento.id!);
                                      await _carregarDados();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  '🗑️ "${lancamento.descricao}" excluído!'),
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
                                  if (descricaoCtrl.text.isEmpty ||
                                      valorCtrl.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Preencha descrição e valor!')),
                                    );
                                    return;
                                  }
                                  Navigator.pop(context);
                                  final lancamentoAtualizado = Lancamento(
                                    id: lancamento.id,
                                    descricao: descricaoCtrl.text,
                                    tipo: tipo == 'receita'
                                        ? TipoLancamento.receita
                                        : TipoLancamento.gasto,
                                    categoria: categoria,
                                    valor: double.parse(
                                        valorCtrl.text.replaceAll(',', '.')),
                                    data: data,
                                    observacao: observacaoCtrl.text.isNotEmpty
                                        ? observacaoCtrl.text
                                        : null,
                                  );
                                  try {
                                    await _supabaseService
                                        .updateLancamento(lancamentoAtualizado);
                                    await _carregarDados();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                '✅ Lançamento atualizado!'),
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
    final meses = [
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

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
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
                                      '${meses[_mesSelecionado.month - 1]} ${_mesSelecionado.year}',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              AppColors.textPrimary(context))),
                                  const SizedBox(width: 8),
                                  IconButton(
                                      icon: const Icon(Icons.chevron_right,
                                          size: 18),
                                      onPressed: () => _navegarMes(1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints()),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: _adicionarLancamento,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20))),
                                child: const Row(children: [
                                  Icon(Icons.add, size: 16),
                                  SizedBox(width: 6),
                                  Text('ADICIONAR',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildResumoCard('Saldo', _saldo, AppColors.primary),
                        const SizedBox(width: 12),
                        _buildResumoCard(
                            'Receitas', _totalReceitas, AppColors.success),
                        const SizedBox(width: 12),
                        _buildResumoCard(
                            'Despesas', _totalDespesas, AppColors.error),
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
                              borderRadius: BorderRadius.circular(20)),
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
                              borderRadius: BorderRadius.circular(20)),
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
                            items: _categorias
                                .map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Row(children: [
                                      Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                              color: _getCategoriaCor(cat),
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(cat),
                                    ])))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _filtroCategoria = value!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _lancamentosFiltrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt,
                                    size: 64, color: AppColors.muted(context)),
                                const SizedBox(height: 16),
                                Text('Nenhum lançamento',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color:
                                            AppColors.textSecondary(context))),
                                const SizedBox(height: 8),
                                Text('Clique em ADICIONAR para começar',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textHint(context))),
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
                              itemBuilder: (context, index) {
                                final l = _lancamentosFiltrados[index];
                                return _buildLancamentoCard(l);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildResumoCard(String titulo, double valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
            color: AppColors.cardBackground(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary(context))),
            const SizedBox(height: 4),
            Text(Formatador.moeda(valor),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
          ],
        ),
      ),
    );
  }

  Widget _buildLancamentoCard(Lancamento lancamento) {
    final isReceita = lancamento.tipo == TipoLancamento.receita;
    final cor = isReceita ? AppColors.success : AppColors.error;
    final icone = isReceita ? Icons.arrow_upward : Icons.arrow_downward;
    final prefixo = isReceita ? '+' : '-';
    final categoriaCor = _getCategoriaCor(lancamento.categoria);
    final isAuto =
        lancamento.observacao?.contains('Pago automaticamente') ?? false;

    return Dismissible(
      key: Key(
          lancamento.id ?? DateTime.now().millisecondsSinceEpoch.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir'),
            content: Text('Excluir "${lancamento.descricao}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Excluir',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        try {
          await _supabaseService.deleteLancamento(lancamento.id!);
          await _carregarDados();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('🗑️ "${lancamento.descricao}" excluído!'),
                  backgroundColor: Colors.orange),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Erro: $e'), backgroundColor: AppColors.error),
            );
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border(context), width: 1)),
        elevation: 0,
        color: AppColors.cardBackground(context),
        child: InkWell(
          onTap: () => _editarLancamento(lancamento),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: cor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icone, color: cor, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lancamento.descricao,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context))),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: categoriaCor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: categoriaCor,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(lancamento.categoria,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: categoriaCor,
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                          Text(Formatador.data(lancamento.data),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary(context))),
                          if (isAuto)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.info.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule,
                                        size: 8, color: AppColors.info),
                                    const SizedBox(width: 4),
                                    Text('Automático',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: AppColors.info,
                                            fontWeight: FontWeight.w500)),
                                  ]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$prefixo ${Formatador.moeda(lancamento.valor)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cor)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5)),
                            child: Icon(Icons.edit,
                                size: 12, color: AppColors.primary)),
                        const SizedBox(width: 4),
                        Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5)),
                            child: const Icon(Icons.delete_outline,
                                size: 12, color: AppColors.error)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoriaCor(String categoria) {
    final cores = {
      'Salário': Colors.green,
      'Bico ou Extra': Colors.orange,
      'Venda de Ativos': Colors.purple,
      'Transporte': Colors.blue,
      'Alimentação': Colors.orange,
      'Moradia': Colors.green,
      'Lazer': Colors.pink,
      'Saúde': Colors.red,
      'Educação': Colors.purple,
      'Água': Colors.cyan,
      'Luz': Colors.yellow,
      'Internet': Colors.blue,
    };
    return cores[categoria] ?? Colors.grey;
  }
}
