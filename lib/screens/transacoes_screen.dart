import '../services/logger_service.dart';
// lib/screens/transacoes_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
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
  final DBHelper _dbHelper = DBHelper();

  List<Transacao> _transacoes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregarTransacoes();
  }

  Future<void> _carregarTransacoes() async {
    setState(() => _loading = true);
    try {
      final db = await _dbHelper.database;
      final query = db.query(
        'transacoes',
        orderBy: 'data DESC',
      );

      if (widget.ticker != null) {
        final transacoes = await query;
        _transacoes = transacoes
            .where((t) => t['ticker'] == widget.ticker)
            .map((json) => Transacao.fromMap(json))
            .toList();
      } else {
        final transacoes = await query;
        _transacoes =
            transacoes.map((json) => Transacao.fromMap(json)).toList();
      }
    } catch (e) {
      LoggerService.info('Erro ao carregar transações: $e');
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

  void _voltar() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: _voltar,
          tooltip: 'Voltar',
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
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _voltar,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Voltar para Investimentos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
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
            color: cor.withValues(alpha:0.3),
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cor.withValues(alpha:0.1),
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
        ),
      ),
    );
  }
}

