// lib/widgets/lancamento_modal.dart
import 'package:flutter/material.dart';
import '../models/lancamento_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';

class LancamentoModal extends StatefulWidget {
  final Lancamento? lancamento;
  final Function(Lancamento) onSave;

  const LancamentoModal({
    super.key,
    this.lancamento,
    required this.onSave,
  });

  @override
  State<LancamentoModal> createState() => _LancamentoModalState();

  static Future<void> show({
    required BuildContext context,
    Lancamento? lancamento,
    required Function(Lancamento) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha:0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: LancamentoModal(
          lancamento: lancamento,
          onSave: onSave,
        ),
      ),
    );
  }
}

class _LancamentoModalState extends State<LancamentoModal> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();

  late TipoLancamento _tipo;
  late String _categoria;
  late DateTime _data;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.lancamento != null) {
      _descricaoController.text = widget.lancamento!.descricao;
      _valorController.text =
          widget.lancamento!.valor.toStringAsFixed(2).replaceAll('.', ',');
      _observacaoController.text = widget.lancamento!.observacao ?? '';
      _tipo = widget.lancamento!.tipo;
      _categoria = widget.lancamento!.categoria;
      _data = widget.lancamento!.data;
    } else {
      _tipo = TipoLancamento.gasto;
      _categoria = 'Outros';
      _data = DateTime.now();
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  List<String> get _categorias {
    return _tipo == TipoLancamento.receita
        ? AppCategories.receitas
        : AppCategories.gastos;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final valor = double.parse(_valorController.text.replaceAll(',', '.'));

      final lancamento = Lancamento(
        id: widget.lancamento?.id,
        descricao: _descricaoController.text,
        tipo: _tipo,
        categoria: _categoria,
        valor: valor,
        data: _data,
        observacao: _observacaoController.text.isNotEmpty
            ? _observacaoController.text
            : null,
      );

      await widget.onSave(lancamento);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lançamentos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.lancamento != null
                            ? 'Editar transação'
                            : 'Controle de receitas e pagamentos',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha:0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.2),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Formulário
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mês
                    Text(
                      _formatarMes(_data),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tipo
                    const Text(
                      'Tipo',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTipoButton(
                            label: 'Receita',
                            tipo: TipoLancamento.receita,
                            color: Colors.green,
                            icon: Icons.arrow_upward,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTipoButton(
                            label: 'Despesa',
                            tipo: TipoLancamento.gasto,
                            color: Colors.red,
                            icon: Icons.arrow_downward,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Descrição
                    const Text(
                      'Descrição',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descricaoController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Supermercado',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite uma descrição';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Valor
                    const Text(
                      'Valor (R\$)',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _valorController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0,00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite um valor';
                        }
                        final val = double.tryParse(value.replaceAll(',', '.'));
                        if (val == null || val <= 0) {
                          return 'Digite um valor válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Categoria
                    const Text(
                      'Categoria',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _categoria,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        hint: const Text('Selecionar'),
                        items: _categorias.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppCategories.getColor(cat),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(cat),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _categoria = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data
                    const Text(
                      'Data',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _data,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _data = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              Formatador.data(_data),
                              style: const TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.calendar_today,
                                color: Colors.grey[600], size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Observação
                    const Text(
                      'Observações',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _observacaoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Opcional',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botões
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _salvar,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    widget.lancamento != null
                                        ? 'ATUALIZAR'
                                        : 'SALVAR',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoButton({
    required String label,
    required TipoLancamento tipo,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _tipo == tipo;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tipo = tipo;
          // 🔥 RESETA A CATEGORIA PARA EVITAR ERRO NO DROPDOWN
          if (tipo == TipoLancamento.receita) {
            _categoria = AppCategories.receitas.first;
          } else {
            _categoria = AppCategories.gastos.first;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha:0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatarMes(DateTime data) {
    final meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return '${meses[data.month - 1]} De ${data.year}';
  }
}

