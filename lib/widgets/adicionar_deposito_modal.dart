// lib/widgets/adicionar_deposito_modal.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/gradient_button.dart';

class AdicionarDepositoModal extends StatefulWidget {
  final int metaId;
  final double valorAtual;
  final double valorObjetivo;
  final Future<void> Function()? onDepositoAdicionado;

  const AdicionarDepositoModal({
    super.key,
    required this.metaId,
    required this.valorAtual,
    required this.valorObjetivo,
    this.onDepositoAdicionado,
  });

  @override
  State<AdicionarDepositoModal> createState() => _AdicionarDepositoModalState();

  static Future<void> show({
    required BuildContext context,
    required int metaId,
    required double valorAtual,
    required double valorObjetivo,
    Future<void> Function()? onDepositoAdicionado,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AdicionarDepositoModal(
          metaId: metaId,
          valorAtual: valorAtual,
          valorObjetivo: valorObjetivo,
          onDepositoAdicionado: onDepositoAdicionado,
        ),
      ),
    );
  }
}

class _AdicionarDepositoModalState extends State<AdicionarDepositoModal> {
  final DBHelper _dbHelper = DBHelper();
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _observacaoController = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  double _parseValor(String texto) {
    try {
      // Remove "R$" e espaços
      String cleaned = texto.replaceAll('R\$', '').trim();
      // Substitui vírgula por ponto
      cleaned = cleaned.replaceAll(',', '.');
      // Remove tudo que não é número ou ponto
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.parse(cleaned);
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _salvarDeposito() async {
    if (_valorController.text.isEmpty) {
      _mostrarErro('Digite o valor do depósito');
      return;
    }

    final double valor = _parseValor(_valorController.text);
    if (valor <= 0) {
      _mostrarErro('O valor deve ser maior que zero');
      return;
    }

    final double valorAtual = widget.valorAtual;
    final double valorObjetivo = widget.valorObjetivo;
    final double novoTotal = valorAtual + valor;
    final double valorRestante =
        (valorObjetivo - valorAtual).clamp(0.0, valorObjetivo);

    // ✅ Comparação correta entre doubles
    if (valor > valorRestante) {
      // ✅ Formatação correta do valorRestante
      final String valorRestanteFormatado = Formatador.moeda(valorRestante);
      _mostrarErro('O valor ultrapassa a meta (Máx: $valorRestanteFormatado)');
      return;
    }

    setState(() => _carregando = true);

    try {
      // Inserir depósito
      await _dbHelper.insertDepositoMeta({
        'meta_id': widget.metaId,
        'valor': valor,
        'data_deposito': DateTime.now().toIso8601String(),
        'observacao': _observacaoController.text,
      });

      // Atualizar valor atual da meta
      await _dbHelper.atualizarProgressoMeta(widget.metaId, novoTotal);

      // Verificar se atingiu a meta
      if (novoTotal >= valorObjetivo) {
        await _dbHelper.concluirMeta(widget.metaId);
      }

      if (mounted) {
        if (widget.onDepositoAdicionado != null) {
          await widget.onDepositoAdicionado!();
        }
        Navigator.pop(context);

        final bool atingiu = (novoTotal >= valorObjetivo);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(atingiu
                ? '🎉 Parabéns! Meta alcançada!'
                : '✅ Depósito adicionado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _mostrarErro('Erro ao adicionar: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
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

  @override
  Widget build(BuildContext context) {
    final double valorAtual = widget.valorAtual;
    final double valorObjetivo = widget.valorObjetivo;
    final double valorRestante =
        (valorObjetivo - valorAtual).clamp(0.0, valorObjetivo);

    return Column(
      children: [
        // CABEÇALHO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Adicionar Depósito',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // FORMULÁRIO
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info da meta
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progresso atual:',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          Text(
                            Formatador.moeda(valorAtual),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Falta:',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          Text(
                            Formatador.moeda(valorRestante),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Valor do depósito
                Text(
                  'Valor do depósito',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _valorController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: '0,00',
                    hintStyle: TextStyle(color: AppColors.textHint(context)),
                    prefixIcon:
                        Icon(Icons.attach_money, color: AppColors.primary),
                    prefixText: 'R\$ ',
                    filled: true,
                    fillColor: AppColors.surface(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Observação
                Text(
                  'Observação (opcional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _observacaoController,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Ex: Depósito mensal, Bônus, etc',
                    hintStyle: TextStyle(color: AppColors.textHint(context)),
                    prefixIcon: Icon(Icons.note, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surface(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Botões
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                              color: AppColors.textSecondary(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _carregando
                          ? const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : GradientButton(
                              text: 'ADICIONAR',
                              onPressed: _salvarDeposito,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
