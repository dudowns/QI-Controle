// lib/widgets/adicionar_investimento_modal.dart
import 'package:flutter/material.dart';
import '../models/investimento_model.dart';
import '../constants/app_colors.dart';

class AdicionarInvestimentoModal {
  static Future<void> show({
    required BuildContext context,
    required Function(Investimento) onSave,
    Investimento? investimento,
  }) async {
    final isEditing = investimento != null;
    final formKey = GlobalKey<FormState>();

    final tickerController =
        TextEditingController(text: investimento?.ticker ?? '');
    final tipoController =
        TextEditingController(text: investimento?.tipo ?? 'ACAO');
    final quantidadeController = TextEditingController(
      text: investimento?.quantidade.toString() ?? '',
    );
    final precoMedioController = TextEditingController(
      text: investimento?.precoMedio.toString() ?? '',
    );
    final precoAtualController = TextEditingController(
      text: investimento?.precoAtual?.toString() ?? '',
    );
    final corretoraController =
        TextEditingController(text: investimento?.corretora ?? '');

    final List<String> tipos = ['ACAO', 'FII', 'ETF', 'BDR', 'CRIPTO'];
    String? tipoSelecionado = investimento?.tipo ?? 'ACAO';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Investimento' : 'Novo Investimento'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: tickerController,
                  decoration: const InputDecoration(
                    labelText: 'Ticker',
                    hintText: 'Ex: PETR4, VISC11',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: tipoSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: tipos.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(TipoInvestimento.getNomeAmigavel(tipo)),
                    );
                  }).toList(),
                  onChanged: (value) => tipoSelecionado = value,
                  validator: (value) =>
                      value == null ? 'Selecione o tipo' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: quantidadeController,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty == true ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: precoMedioController,
                  decoration: const InputDecoration(
                    labelText: 'Preço Médio',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty == true ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: precoAtualController,
                  decoration: const InputDecoration(
                    labelText: 'Preço Atual (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: corretoraController,
                  decoration: const InputDecoration(
                    labelText: 'Corretora (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final novoInvestimento = Investimento(
                  id: investimento?.id,
                  ticker: tickerController.text.toUpperCase(),
                  tipo: tipoSelecionado!,
                  quantidade: double.parse(quantidadeController.text),
                  precoMedio: double.parse(precoMedioController.text),
                  precoAtual: precoAtualController.text.isNotEmpty
                      ? double.parse(precoAtualController.text)
                      : null,
                  corretora: corretoraController.text.isNotEmpty
                      ? corretoraController.text
                      : null,
                );
                Navigator.pop(context);
                onSave(novoInvestimento);
              }
            },
            child: Text(isEditing ? 'Salvar' : 'Adicionar'),
          ),
        ],
      ),
    );
  }
}
