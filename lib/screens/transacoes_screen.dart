// lib/screens/transacoes_screen.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

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
  final SupabaseService _supabase = SupabaseService();
  List<Map<String, dynamic>> _transacoes = [];
  bool _loading = true;
  bool _deletando = false;

  @override
  void initState() {
    super.initState();
    _carregarTransacoes();
  }

  Future<void> _carregarTransacoes() async {
    setState(() => _loading = true);
    try {
      if (widget.ticker != null) {
        _transacoes = await _supabase.getTransacoesByTicker(widget.ticker!);
      } else {
        _transacoes = await _supabase.getUltimasTransacoes();
      }
    } catch (e) {
      debugPrint('Erro ao carregar transações: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletarTransacao(int id, String ticker) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Transação'),
        content:
            Text('Tem certeza que deseja excluir esta transação de $ticker?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _deletando = true);
      try {
        await _supabase.deleteTransacao(id);
        await _carregarTransacoes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Transação de $ticker excluída!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        debugPrint('Erro ao excluir: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _deletando = false);
      }
    }
  }

  void _mostrarModalAdicionar() {
    final tickerCtrl = TextEditingController(text: widget.ticker);
    final quantidadeCtrl = TextEditingController();
    final precoCtrl = TextEditingController();
    final taxaCtrl = TextEditingController();
    String tipoTransacao = 'COMPRA';
    String tipoInvestimento = widget.tipoInvestimento ?? 'ACAO';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            title: const Text('Nova Transação'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tickerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ticker',
                      hintText: 'PETR4, VISC11, BTC',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.abc),
                    ),
                    enabled: widget.ticker == null,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  if (widget.ticker == null)
                    DropdownButtonFormField<String>(
                      initialValue: tipoInvestimento,
                      decoration: const InputDecoration(
                        labelText: 'Tipo do Investimento',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'ACAO', child: Text('📈 Ações')),
                        DropdownMenuItem(value: 'FII', child: Text('🏢 FIIs')),
                        DropdownMenuItem(
                            value: 'CRIPTO', child: Text('🪙 Criptomoedas')),
                        DropdownMenuItem(
                            value: 'RENDA_FIXA', child: Text('🏦 Renda Fixa')),
                      ],
                      onChanged: (value) {
                        setStateModal(() {
                          tipoInvestimento = value!;
                        });
                      },
                    ),
                  if (widget.ticker == null) const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTipoButton(
                            'COMPRA',
                            Icons.trending_up,
                            AppColors.success,
                            tipoTransacao,
                            (v) => setStateModal(() => tipoTransacao = v)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTipoButton(
                            'VENDA',
                            Icons.trending_down,
                            AppColors.error,
                            tipoTransacao,
                            (v) => setStateModal(() => tipoTransacao = v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantidadeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      hintText: 'Ex: 100',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: precoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Preço Unitário (R\$)',
                      hintText: 'Ex: 28.50',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: taxaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Taxa (R\$) - Opcional',
                      hintText: 'Ex: 5.00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (tickerCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Digite o ticker!')),
                    );
                    return;
                  }
                  if (quantidadeCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Digite a quantidade!')),
                    );
                    return;
                  }
                  if (precoCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Digite o preço!')),
                    );
                    return;
                  }

                  final quantidade = double.tryParse(quantidadeCtrl.text);
                  final preco = double.tryParse(precoCtrl.text);
                  final taxa = taxaCtrl.text.isNotEmpty
                      ? (double.tryParse(taxaCtrl.text) ?? 0).toDouble()
                      : 0.0;

                  if (quantidade == null || preco == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Valores inválidos!')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  try {
                    await _supabase.inserirTransacao(
                      ticker: tickerCtrl.text,
                      tipoInvestimento: tipoInvestimento,
                      tipoTransacao: tipoTransacao,
                      quantidade: quantidade,
                      precoUnitario: preco,
                      taxa: taxa,
                    );

                    await _carregarTransacoes();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ ${tickerCtrl.text.toUpperCase()} - ${tipoTransacao == 'COMPRA' ? 'Compra' : 'Venda'} registrada!',
                          ),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTipoButton(String texto, IconData icon, Color cor,
      String tipoAtual, Function(String) onTap) {
    final isSelected = tipoAtual == texto;
    return GestureDetector(
      onTap: () => onTap(texto),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? cor : Colors.grey[300]!,
              width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? cor : Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            Text(texto,
                style: TextStyle(color: isSelected ? cor : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.ticker != null
              ? 'Transações - ${widget.ticker}'
              : 'Últimas Transações',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarTransacoes,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transacoes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma transação ainda',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registre suas compras e vendas',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _mostrarModalAdicionar,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Transação'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _transacoes.length,
                  itemBuilder: (context, index) {
                    final t = _transacoes[index];
                    final isCompra = t['tipo_transacao'] == 'COMPRA';
                    final quantidade = (t['quantidade'] as num).toDouble();
                    final preco = (t['preco_unitario'] as num).toDouble();
                    final taxa = (t['taxa'] as num?)?.toDouble() ?? 0;
                    final valorTotal = quantidade * preco + taxa;
                    final data = DateTime.parse(t['data']);

                    return Dismissible(
                      key: Key(t['id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Excluir Transação'),
                            content: Text(
                              'Excluir ${isCompra ? 'compra' : 'venda'} de ${quantidade.toStringAsFixed(2)} ${t['ticker']}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                ),
                                child: const Text('Excluir'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        _deletarTransacao(t['id'], t['ticker']);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCompra
                                  ? AppColors.success.withOpacity(0.3)
                                  : AppColors.error.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCompra
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isCompra
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: isCompra
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 24,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['ticker'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isCompra ? 'Compra' : 'Venda',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isCompra
                                              ? AppColors.success
                                              : AppColors.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatador.moeda(valorTotal),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isCompra
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatador.data(data),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${quantidade.toStringAsFixed(2)} cotas × ${Formatador.moeda(preco)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                  if (taxa > 0)
                                    Text(
                                      'Taxa: ${Formatador.moeda(taxa)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarModalAdicionar,
        icon: const Icon(Icons.add),
        label: const Text('Nova Transação'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
