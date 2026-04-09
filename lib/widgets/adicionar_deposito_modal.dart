// lib/widgets/adicionar_deposito_modal.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

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
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
  bool _isLoading = false;

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  double _parseValor(String texto) {
    try {
      String cleaned = texto.replaceAll('R\$', '').trim();
      cleaned = cleaned.replaceAll(',', '.');
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

    if (valor > valorRestante) {
      final String valorRestanteFormatado = Formatador.moeda(valorRestante);
      _mostrarErro('O valor ultrapassa a meta (Máx: $valorRestanteFormatado)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _dbHelper.insertDepositoMeta({
        'meta_id': widget.metaId,
        'valor': valor,
        'data_deposito': DateTime.now().toIso8601String(),
        'observacao': _observacaoController.text,
      });

      await _dbHelper.atualizarProgressoMeta(widget.metaId, novoTotal);

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
      if (mounted) setState(() => _isLoading = false);
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

    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 450, maxHeight: 480),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader('Adicionar Depósito', context),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B2CBF).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF7B2CBF).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progresso atual:',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              Formatador.moeda(valorAtual),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Falta:'),
                            Text(
                              Formatador.moeda(valorRestante),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7B2CBF),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Valor do depósito',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _valorController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF7B2CBF), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Observação (opcional)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _observacaoController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ex: Depósito mensal, Bônus, etc',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF7B2CBF), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancelar',
                              style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _salvarDeposito,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7B2CBF),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'ADICIONAR',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
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
  }

  Widget _buildHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, size: 20, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
