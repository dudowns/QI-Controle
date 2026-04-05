// lib/screens/transacoes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/transacao_model.dart';
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
  late final SupabaseService _supabaseService;

  List<Transacao> _transacoes = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _supabaseService = Provider.of<SupabaseService>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _carregarTransacoes();
  }

  Future<void> _carregarTransacoes() async {
    setState(() => _loading = true);
    try {
      if (widget.ticker != null) {
        _transacoes =
            await _supabaseService.getTransacoesByTicker(widget.ticker!);
      } else {
        _transacoes = await _supabaseService.getTransacoes();
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

  /// Navega de volta para a tela de investimentos
  void _voltarParaInvestimentos() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        // 🔥 BOTÃO DE VOLTAR ESTILIZADO
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: _voltarParaInvestimentos,
          tooltip: 'Voltar para Investimentos',
        ),
        title: Text(
          widget.ticker != null
              ? 'Movimentações - ${widget.ticker}'
              : 'Histórico de Movimentações',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                        'Nenhuma movimentação registrada',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'As compras e vendas aparecerão aqui',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
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
                    final isCompra = t.tipo == 'COMPRA';
                    final quantidade = t.quantidade;
                    final preco = t.preco;
                    final taxa = t.taxa ?? 0;
                    final valorTotal = quantidade * preco + taxa;

                    // 🔥 CARD SEM BOTÕES DE EDITAR/EXCLUIR
                    return _buildTransacaoCard(
                      transacao: t,
                      isCompra: isCompra,
                      quantidade: quantidade,
                      preco: preco,
                      taxa: taxa,
                      valorTotal: valorTotal,
                    );
                  },
                ),
    );
  }

  /// Constrói o card da transação (sem botões de ação)
  Widget _buildTransacaoCard({
    required Transacao transacao,
    required bool isCompra,
    required double quantidade,
    required double preco,
    required double taxa,
    required double valorTotal,
  }) {
    final cor = isCompra ? AppColors.success : AppColors.error;
    final icone = isCompra ? Icons.trending_up : Icons.trending_down;
    final titulo = isCompra ? 'Compra' : 'Venda';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icone,
              color: cor,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transacao.ticker,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 12,
                        color: cor,
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
                      color: cor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatador.data(transacao.data),
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
          // 🔥 SEM onTap para não abrir modal de edição
          // 🔥 SEM botões de editar/excluir
        ),
      ),
    );
  }
}
