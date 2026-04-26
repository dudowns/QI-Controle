// lib/widgets/app_modals.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';
import '../services/theme_service.dart';

class AppModals {
  // ========== 1. MODAL DE LANÇAMENTO ==========
  static Future<Map<String, dynamic>?> mostrarModalLancamento({
    required BuildContext context,
    Map<String, dynamic>? lancamento,
  }) async {
    final isEditing = lancamento != null;
    final isDark = ThemeService().isDarkMode;

    final descricaoCtrl =
        TextEditingController(text: lancamento?['descricao'] ?? '');
    final valorCtrl = TextEditingController(
      text: lancamento != null && lancamento['valor'] != null
          ? (lancamento['valor'] as num).toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    final observacaoCtrl =
        TextEditingController(text: lancamento?['observacao'] ?? '');

    String tipo = lancamento?['tipo'] ?? 'gasto';
    String categoria = lancamento?['categoria'] ?? 'Outros';
    DateTime data = lancamento != null && lancamento['data'] != null
        ? DateTime.parse(lancamento['data'])
        : DateTime.now();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                  _buildHeader(
                      isEditing ? 'Editar Lançamento' : 'Novo Lançamento',
                      context,
                      isDark: isDark),
                  Divider(
                      height: 1,
                      color:
                          isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: _buildTipoBotao(
                                label: 'Receita',
                                value: 'receita',
                                icon: Icons.trending_up,
                                selected: tipo == 'receita',
                                onTap: () => setState(() => tipo = 'receita'),
                                isDark: isDark,
                              )),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildTipoBotao(
                                label: 'Despesa',
                                value: 'gasto',
                                icon: Icons.trending_down,
                                selected: tipo == 'gasto',
                                onTap: () => setState(() => tipo = 'gasto'),
                                isDark: isDark,
                              )),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(descricaoCtrl, 'Descrição',
                              isDark: isDark),
                          const SizedBox(height: 16),
                          _buildTextField(valorCtrl, 'Valor',
                              isDark: isDark, prefix: 'R\$ ', isNumber: true),
                          const SizedBox(height: 16),
                          _buildDropdownCategoria(categoria, tipo == 'receita',
                              (value) => setState(() => categoria = value),
                              isDark: isDark),
                          const SizedBox(height: 16),
                          _buildDatePicker(context, data,
                              (date) => setState(() => data = date),
                              isDark: isDark),
                          const SizedBox(height: 16),
                          _buildTextField(
                              observacaoCtrl, 'Observação (opcional)',
                              isDark: isDark, maxLines: 2),
                          const SizedBox(height: 24),
                          _buildButtons(
                            context: context,
                            onCancel: () => Navigator.pop(context),
                            onConfirm: () {
                              if (descricaoCtrl.text.isEmpty ||
                                  valorCtrl.text.isEmpty) {
                                _showSnackBar(
                                    context, 'Preencha descrição e valor');
                                return;
                              }
                              final resultado = {
                                'descricao': descricaoCtrl.text,
                                'valor': double.parse(
                                    valorCtrl.text.replaceAll(',', '.')),
                                'tipo': tipo,
                                'categoria': categoria,
                                'data': data.toIso8601String(),
                                'observacao': observacaoCtrl.text,
                              };
                              if (isEditing) {
                                final id = lancamento['id'];
                                if (id != null) {
                                  resultado['id'] = id;
                                }
                              }
                              Navigator.pop(context, resultado);
                            },
                            isEditing: isEditing,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== 2. MODAL DE INVESTIMENTO ==========
  static Future<Map<String, dynamic>?> mostrarModalInvestimento({
    required BuildContext context,
    Map<String, dynamic>? investimento,
  }) async {
    final isEditing = investimento != null;
    final isDark = ThemeService().isDarkMode;

    final tickerCtrl =
        TextEditingController(text: investimento?['ticker'] ?? '');
    final quantidadeCtrl = TextEditingController(
      text: investimento != null && investimento['quantidade'] != null
          ? (investimento['quantidade'] as num).toString()
          : '',
    );
    final precoMedioCtrl = TextEditingController(
      text: investimento != null && investimento['preco_medio'] != null
          ? (investimento['preco_medio'] as num)
              .toStringAsFixed(2)
              .replaceAll('.', ',')
          : '',
    );
    final precoAtualCtrl = TextEditingController(
      text: investimento != null && investimento['preco_atual'] != null
          ? (investimento['preco_atual'] as num)
              .toStringAsFixed(2)
              .replaceAll('.', ',')
          : '',
    );

    String tipoSelecionado = investimento?['tipo'] ?? 'ACAO';
    final List<String> tipos = ['ACAO', 'FII', 'CRIPTO', 'RENDA_FIXA'];

    DateTime dataCompra =
        investimento != null && investimento['data_compra'] != null
            ? DateTime.parse(investimento['data_compra'])
            : DateTime.now();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(
                      isEditing ? 'Editar Investimento' : 'Novo Investimento',
                      context,
                      isDark: isDark),
                  Divider(
                      height: 1,
                      color:
                          isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(tickerCtrl, 'Ticker',
                              isDark: isDark, hint: 'Ex: PETR4, VISC11'),
                          const SizedBox(height: 16),
                          _buildDropdownTipos(
                              tipoSelecionado,
                              tipos,
                              (value) =>
                                  setState(() => tipoSelecionado = value),
                              isDark: isDark),
                          const SizedBox(height: 16),
                          _buildTextField(quantidadeCtrl, 'Quantidade',
                              isDark: isDark, isNumber: true),
                          const SizedBox(height: 16),
                          _buildTextField(precoMedioCtrl, 'Preço Médio',
                              isDark: isDark, prefix: 'R\$ ', isNumber: true),
                          const SizedBox(height: 16),
                          _buildTextField(
                              precoAtualCtrl, 'Preço Atual (opcional)',
                              isDark: isDark, prefix: 'R\$ ', isNumber: true),
                          const SizedBox(height: 16),
                          _buildDatePicker(
                            context,
                            dataCompra,
                            (date) => setState(() => dataCompra = date),
                            label: 'Data da Compra',
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 24),
                          _buildButtons(
                            context: context,
                            onCancel: () => Navigator.pop(context),
                            onConfirm: () {
                              if (tickerCtrl.text.isEmpty ||
                                  quantidadeCtrl.text.isEmpty ||
                                  precoMedioCtrl.text.isEmpty) {
                                _showSnackBar(context,
                                    'Preencha todos os campos obrigatórios');
                                return;
                              }
                              final resultado = {
                                'ticker': tickerCtrl.text.toUpperCase(),
                                'tipo': tipoSelecionado,
                                'quantidade': double.parse(
                                    quantidadeCtrl.text.replaceAll(',', '.')),
                                'preco_medio': double.parse(
                                    precoMedioCtrl.text.replaceAll(',', '.')),
                                'preco_atual': precoAtualCtrl.text.isNotEmpty
                                    ? double.parse(precoAtualCtrl.text
                                        .replaceAll(',', '.'))
                                    : null,
                                'data_compra': dataCompra.toIso8601String(),
                              };
                              if (isEditing) {
                                final id = investimento['id'];
                                if (id != null) {
                                  resultado['id'] = id;
                                }
                              }
                              Navigator.pop(context, resultado);
                            },
                            isEditing: isEditing,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== 3. MODAL DE PROVENTO ==========
  static Future<Map<String, dynamic>?> mostrarModalProvento({
    required BuildContext context,
    Map<String, dynamic>? provento,
    required List<String> tickersDisponiveis,
  }) async {
    final isEditing = provento != null;
    final isDark = ThemeService().isDarkMode;

    final tickerCtrl = TextEditingController(
        text: provento?['ticker'] ??
            (tickersDisponiveis.isNotEmpty ? tickersDisponiveis.first : ''));
    final valorCtrl = TextEditingController(
      text: provento != null && provento['valor_por_cota'] != null
          ? (provento['valor_por_cota'] as num)
              .toStringAsFixed(2)
              .replaceAll('.', ',')
          : '',
    );
    final quantidadeCtrl = TextEditingController(
      text: provento != null && provento['quantidade'] != null
          ? (provento['quantidade'] as num).toString()
          : '1',
    );

    DateTime dataPagamento =
        provento != null && provento['data_pagamento'] != null
            ? DateTime.parse(provento['data_pagamento'])
            : DateTime.now();
    DateTime? dataCom = provento != null && provento['data_com'] != null
        ? DateTime.parse(provento['data_com'])
        : null;

    String tipoProvento = provento?['tipo_provento'] ?? 'Dividendo';
    final List<String> tiposProvento = [
      'Dividendo',
      'JCP',
      'Rendimento',
      'Amortização'
    ];

    bool temDataCom = dataCom != null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(
                      isEditing ? 'Editar Provento' : 'Novo Provento', context,
                      isDark: isDark),
                  Divider(
                      height: 1,
                      color:
                          isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tickersDisponiveis.isNotEmpty)
                            _buildDropdownTickers(
                                tickerCtrl,
                                tickersDisponiveis,
                                (value) => tickerCtrl.text = value ?? '',
                                isDark: isDark),
                          if (tickersDisponiveis.isEmpty)
                            _buildTextField(tickerCtrl, 'Ticker',
                                isDark: isDark, hint: 'Ex: PETR4'),
                          const SizedBox(height: 16),
                          _buildDropdownString(
                              'Tipo',
                              tipoProvento,
                              tiposProvento,
                              (value) => setState(() => tipoProvento = value),
                              isDark: isDark),
                          const SizedBox(height: 16),
                          _buildTextField(valorCtrl, 'Valor por cota',
                              isDark: isDark, prefix: 'R\$ ', isNumber: true),
                          const SizedBox(height: 16),
                          _buildTextField(quantidadeCtrl, 'Quantidade',
                              isDark: isDark, isNumber: true),
                          const SizedBox(height: 16),
                          _buildDatePicker(context, dataPagamento,
                              (date) => setState(() => dataPagamento = date),
                              label: 'Data de pagamento', isDark: isDark),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: temDataCom,
                                onChanged: (value) =>
                                    setState(() => temDataCom = value ?? false),
                                activeColor: const Color(0xFF7B2CBF),
                              ),
                              Text('Possui data COM',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF333333))),
                            ],
                          ),
                          if (temDataCom) ...[
                            const SizedBox(height: 8),
                            _buildDatePicker(context, dataCom ?? DateTime.now(),
                                (date) => setState(() => dataCom = date),
                                label: 'Data COM', isDark: isDark),
                          ],
                          const SizedBox(height: 24),
                          _buildButtons(
                            context: context,
                            onCancel: () => Navigator.pop(context),
                            onConfirm: () {
                              if (tickerCtrl.text.isEmpty ||
                                  valorCtrl.text.isEmpty ||
                                  quantidadeCtrl.text.isEmpty) {
                                _showSnackBar(context,
                                    'Preencha todos os campos obrigatórios');
                                return;
                              }
                              final resultado = {
                                'ticker': tickerCtrl.text.toUpperCase(),
                                'tipo_provento': tipoProvento,
                                'valor_por_cota': double.parse(
                                    valorCtrl.text.replaceAll(',', '.')),
                                'quantidade': double.parse(
                                    quantidadeCtrl.text.replaceAll(',', '.')),
                                'data_pagamento':
                                    dataPagamento.toIso8601String(),
                                'data_com': temDataCom && dataCom != null
                                    ? dataCom!.toIso8601String()
                                    : null,
                              };
                              if (isEditing) {
                                final id = provento['id'];
                                if (id != null) {
                                  resultado['id'] = id;
                                }
                              }
                              Navigator.pop(context, resultado);
                            },
                            isEditing: isEditing,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== 4. MODAL DE CONTA DO MÊS ==========
  static Future<Map<String, dynamic>?> mostrarModalConta({
    required BuildContext context,
    Map<String, dynamic>? conta,
  }) async {
    final isEditing = conta != null;
    final isDark = ThemeService().isDarkMode;

    final nomeCtrl = TextEditingController(text: conta?['nome'] ?? '');
    final valorCtrl = TextEditingController(
      text: conta != null && conta['valor'] != null
          ? (conta['valor'] as num).toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    int diaVencimento = conta?['dia_vencimento'] ?? 1;
    String tipo = conta?['tipo'] ?? 'mensal';
    String categoria = conta?['categoria'] ?? 'Outros';
    DateTime dataInicio = conta != null && conta['data_inicio'] != null
        ? DateTime.parse(conta['data_inicio'])
        : DateTime.now();
    int? parcelasTotal = conta?['parcelas_total'];

    final List<int> dias = List.generate(31, (i) => i + 1);
    final List<String> tipos = ['mensal', 'parcelada'];
    final List<String> categorias = [
      'Água',
      'Luz',
      'Internet',
      'Telefone',
      'Aluguel',
      'Transporte',
      'Alimentação',
      'Lazer',
      'Saúde',
      'Educação',
      'Cartão de Crédito',
      'Financiamento',
      'Outros'
    ];

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(
                      isEditing ? 'Editar Conta' : 'Nova Conta', context,
                      isDark: isDark),
                  Divider(
                      height: 1,
                      color:
                          isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(nomeCtrl, 'Nome da conta',
                              isDark: isDark, hint: 'Ex: Netflix, Aluguel'),
                          const SizedBox(height: 16),
                          _buildTextField(valorCtrl, 'Valor',
                              isDark: isDark, prefix: 'R\$ ', isNumber: true),
                          const SizedBox(height: 16),
                          _buildDropdownDias(diaVencimento, dias,
                              (value) => setState(() => diaVencimento = value),
                              isDark: isDark),
                          const SizedBox(height: 16),
                          _buildDropdownString('Tipo', tipo, tipos,
                              (value) => setState(() => tipo = value),
                              isDark: isDark),
                          const SizedBox(height: 16),
                          _buildDropdownString(
                              'Categoria',
                              categoria,
                              categorias,
                              (value) => setState(() => categoria = value),
                              isDark: isDark),
                          const SizedBox(height: 16),
                          _buildDatePicker(context, dataInicio,
                              (date) => setState(() => dataInicio = date),
                              label: 'Data de início', isDark: isDark),
                          if (tipo == 'parcelada') ...[
                            const SizedBox(height: 16),
                            _buildTextField(
                                TextEditingController(
                                    text: parcelasTotal?.toString() ?? ''),
                                'Total de parcelas',
                                isDark: isDark,
                                isNumber: true),
                          ],
                          const SizedBox(height: 24),
                          _buildButtons(
                            context: context,
                            onCancel: () => Navigator.pop(context),
                            onConfirm: () {
                              if (nomeCtrl.text.isEmpty ||
                                  valorCtrl.text.isEmpty) {
                                _showSnackBar(context, 'Preencha nome e valor');
                                return;
                              }
                              final resultado = {
                                'nome': nomeCtrl.text,
                                'valor': double.parse(
                                    valorCtrl.text.replaceAll(',', '.')),
                                'dia_vencimento': diaVencimento,
                                'tipo': tipo,
                                'categoria': categoria,
                                'data_inicio': dataInicio.toIso8601String(),
                              };
                              if (tipo == 'parcelada' &&
                                  parcelasTotal != null) {
                                resultado['parcelas_total'] = parcelasTotal;
                              }
                              if (isEditing) {
                                final id = conta['id'];
                                if (id != null) {
                                  resultado['id'] = id;
                                }
                              }
                              Navigator.pop(context, resultado);
                            },
                            isEditing: isEditing,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== 5. MODAL DE META ==========
  static Future<Map<String, dynamic>?> mostrarModalMeta({
    required BuildContext context,
    Map<String, dynamic>? meta,
  }) async {
    final isEditing = meta != null;
    final isDark = ThemeService().isDarkMode;

    final tituloCtrl = TextEditingController(text: meta?['titulo'] ?? '');
    final descricaoCtrl = TextEditingController(text: meta?['descricao'] ?? '');
    final valorCtrl = TextEditingController(
      text: meta != null && meta['valor_objetivo'] != null
          ? (meta['valor_objetivo'] as num)
              .toStringAsFixed(2)
              .replaceAll('.', ',')
          : '',
    );

    DateTime dataFim = meta != null && meta['data_fim'] != null
        ? DateTime.parse(meta['data_fim'])
        : DateTime.now().add(const Duration(days: 30));

    String corSelecionada = meta?['cor'] ?? 'viagem';
    String iconeSelecionado = meta?['icone'] ?? 'viagem';

    final List<Map<String, dynamic>> opcoesTipo = [
      {
        'nome': 'Viagem',
        'cor': 'viagem',
        'icone': 'viagem',
        'color': Colors.blue
      },
      {'nome': 'Carro', 'cor': 'carro', 'icone': 'carro', 'color': Colors.red},
      {'nome': 'Casa', 'cor': 'casa', 'icone': 'casa', 'color': Colors.green},
      {
        'nome': 'Estudo',
        'cor': 'estudo',
        'icone': 'estudo',
        'color': Colors.orange
      },
      {
        'nome': 'Investimento',
        'cor': 'investimento',
        'icone': 'investimento',
        'color': Colors.purple
      },
    ];

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(isEditing ? 'Editar Meta' : 'Nova Meta', context,
                      isDark: isDark),
                  Divider(
                      height: 1,
                      color:
                          isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tipo da meta',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A))),
                          const SizedBox(height: 8),
                          _buildTipoMetaSelector(
                              opcoesTipo,
                              corSelecionada,
                              iconeSelecionado,
                              (cor, icone) => setState(() {
                                    corSelecionada = cor;
                                    iconeSelecionado = icone;
                                  }),
                              isDark: isDark),
                          const SizedBox(height: 20),
                          _buildTextField(tituloCtrl, 'Título',
                              isDark: isDark, hint: 'Ex: Viagem para a praia'),
                          const SizedBox(height: 16),
                          _buildTextField(descricaoCtrl, 'Descrição (opcional)',
                              isDark: isDark, maxLines: 2),
                          const SizedBox(height: 16),
                          _buildTextField(valorCtrl, 'Valor da meta',
                              isDark: isDark, prefix: 'R\$ ', isNumber: true),
                          const SizedBox(height: 16),
                          _buildDatePicker(context, dataFim,
                              (date) => setState(() => dataFim = date),
                              label: 'Data limite',
                              firstDate: DateTime.now(),
                              isDark: isDark),
                          const SizedBox(height: 24),
                          _buildButtons(
                            context: context,
                            onCancel: () => Navigator.pop(context),
                            onConfirm: () {
                              if (tituloCtrl.text.isEmpty ||
                                  valorCtrl.text.isEmpty) {
                                _showSnackBar(
                                    context, 'Preencha título e valor');
                                return;
                              }
                              final valor = double.parse(
                                  valorCtrl.text.replaceAll(',', '.'));
                              if (valor <= 0) {
                                _showSnackBar(
                                    context, 'Digite um valor válido');
                                return;
                              }
                              final resultado = {
                                'titulo': tituloCtrl.text,
                                'descricao': descricaoCtrl.text,
                                'valor_objetivo': valor,
                                'data_fim': dataFim.toIso8601String(),
                                'cor': corSelecionada,
                                'icone': iconeSelecionado,
                              };
                              if (isEditing) {
                                final id = meta['id'];
                                if (id != null) {
                                  resultado['id'] = id;
                                }
                              }
                              Navigator.pop(context, resultado);
                            },
                            isEditing: isEditing,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== 6. MODAL DE DEPÓSITO ==========
  static Future<Map<String, dynamic>?> mostrarModalDeposito({
    required BuildContext context,
    required Map<String, dynamic> meta,
  }) async {
    final isDark = ThemeService().isDarkMode;
    final valorAtual = (meta['valor_atual'] as num?)?.toDouble() ?? 0.0;
    final valorObjetivo = (meta['valor_objetivo'] as num?)?.toDouble() ?? 0.0;
    final valorRestante =
        (valorObjetivo - valorAtual).clamp(0.0, valorObjetivo);
    final valorCtrl = TextEditingController();
    final observacaoCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxWidth: 450, maxHeight: 480),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader('Adicionar Depósito', context, isDark: isDark),
                  Divider(
                      height: 1,
                      color:
                          isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B2CBF)
                                  .withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF7B2CBF)
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Progresso atual:',
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600])),
                                      Text(Formatador.moeda(valorAtual),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ]),
                                const SizedBox(height: 8),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Falta:',
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600])),
                                      Text(Formatador.moeda(valorRestante),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF7B2CBF),
                                              fontSize: 16)),
                                    ]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(valorCtrl, 'Valor do depósito',
                              isDark: isDark, prefix: 'R\$ ', isNumber: true),
                          const SizedBox(height: 16),
                          _buildTextField(
                              observacaoCtrl, 'Observação (opcional)',
                              isDark: isDark, maxLines: 2),
                          const SizedBox(height: 24),
                          _buildButtons(
                            context: context,
                            onCancel: () => Navigator.pop(context),
                            onConfirm: () {
                              if (valorCtrl.text.isEmpty) {
                                _showSnackBar(context, 'Digite o valor');
                                return;
                              }
                              final valor = double.parse(
                                  valorCtrl.text.replaceAll(',', '.'));
                              if (valor <= 0) {
                                _showSnackBar(context, 'Valor inválido');
                                return;
                              }
                              if (valor > valorRestante) {
                                _showSnackBar(context,
                                    'Valor excede a meta (Máx: ${Formatador.moeda(valorRestante)})');
                                return;
                              }
                              Navigator.pop(context, {
                                'valor': valor,
                                'observacao': observacaoCtrl.text
                              });
                            },
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== COMPONENTES REUTILIZÁVEIS ATUALIZADOS ==========

  static Widget _buildHeader(String title, BuildContext context,
      {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close,
                size: 20, color: isDark ? Colors.grey[400] : Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  static Widget _buildTextField(TextEditingController controller, String label,
      {required bool isDark,
      String? hint,
      String prefix = '',
      bool isNumber = false,
      int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(
          fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint ?? label,
        hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : const Color(0xFF999999)),
        prefixText: prefix.isEmpty ? null : prefix,
        prefixStyle: TextStyle(
            color: isDark ? Colors.grey[400] : const Color(0xFF666666)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : const Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      ),
    );
  }

  static Widget _buildDatePicker(
      BuildContext context, DateTime date, Function(DateTime) onChanged,
      {String label = 'Data',
      DateTime? firstDate,
      DateTime? lastDate,
      required bool isDark}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 3650)),
          locale: const Locale('pt', 'BR'),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border:
              Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[500]),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(width: 8),
                Text(
                  Formatador.data(date),
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF333333)),
                ),
              ],
            ),
            Icon(Icons.arrow_drop_down,
                size: 20, color: isDark ? Colors.grey[400] : Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  static Widget _buildTipoBotao({
    required String label,
    required String value,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7B2CBF).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF7B2CBF)
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected
                    ? const Color(0xFF7B2CBF)
                    : (isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? const Color(0xFF7B2CBF)
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                )),
          ],
        ),
      ),
    );
  }

  static Widget _buildDropdownCategoria(
      String value, bool isReceita, Function(String) onChanged,
      {required bool isDark}) {
    final categorias =
        isReceita ? AppCategories.receitas : AppCategories.gastos;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border:
            Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down,
            color: isDark ? Colors.grey[400] : Colors.grey[500]),
        style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF333333)),
        dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        items: categorias.map((cat) {
          return DropdownMenuItem(
            value: cat,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppCategories.getColor(cat),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(cat,
                    style: TextStyle(
                        color:
                            isDark ? Colors.white : const Color(0xFF333333))),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) => onChanged(value ?? ''),
      ),
    );
  }

  static Widget _buildDropdownTipos(
      String value, List<String> tipos, Function(String) onChanged,
      {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border:
            Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down,
            color: isDark ? Colors.grey[400] : Colors.grey[500]),
        style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF333333)),
        dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        items: tipos.map((tipo) {
          return DropdownMenuItem(
            value: tipo,
            child: Text(TipoInvestimento.getNomeAmigavel(tipo),
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF333333))),
          );
        }).toList(),
        onChanged: (value) => onChanged(value ?? 'ACAO'),
      ),
    );
  }

  static Widget _buildDropdownString(String label, String value,
      List<String> items, Function(String) onChanged,
      {required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : const Color(0xFF666666))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down,
                color: isDark ? Colors.grey[400] : Colors.grey[500]),
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF333333)),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            items: items
                .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF333333)))))
                .toList(),
            onChanged: (value) => onChanged(value ?? items.first),
          ),
        ),
      ],
    );
  }

  static Widget _buildDropdownDias(
      int value, List<int> dias, Function(int) onChanged,
      {required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dia de vencimento',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down,
                color: isDark ? Colors.grey[400] : Colors.grey[500]),
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF333333)),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            items: dias
                .map((dia) => DropdownMenuItem(
                    value: dia,
                    child: Text(dia.toString(),
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF333333)))))
                .toList(),
            onChanged: (value) => onChanged(value ?? 1),
          ),
        ),
      ],
    );
  }

  static Widget _buildDropdownTickers(TextEditingController controller,
      List<String> tickers, Function(String?) onChanged,
      {required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ativo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: controller.text.isNotEmpty ? controller.text : null,
            isExpanded: true,
            hint: const Text('Selecione um ativo'),
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down,
                color: isDark ? Colors.grey[400] : Colors.grey[500]),
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF333333)),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            items: tickers
                .map((ticker) => DropdownMenuItem(
                    value: ticker,
                    child: Text(ticker,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF333333)))))
                .toList(),
            onChanged: (value) {
              controller.text = value ?? '';
              onChanged(value);
            },
          ),
        ),
      ],
    );
  }

  static Widget _buildTipoMetaSelector(
      List<Map<String, dynamic>> opcoes,
      String corSelecionada,
      String iconeSelecionado,
      Function(String, String) onChanged,
      {required bool isDark}) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: opcoes.length,
        itemBuilder: (context, index) {
          final opcao = opcoes[index];
          final isSelected = corSelecionada == opcao['cor'];
          return GestureDetector(
            onTap: () => onChanged(opcao['cor'], opcao['icone']),
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (opcao['color'] as Color).withValues(alpha: 0.2)
                    : (isDark ? Colors.grey[800] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? opcao['color'] as Color
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getIconeParaTipo(opcao['icone']),
                      color: isSelected
                          ? opcao['color'] as Color
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      size: 24),
                  const SizedBox(height: 4),
                  Text(
                    opcao['nome'],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? opcao['color'] as Color
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildButtons({
    required BuildContext context,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
    bool isEditing = false,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              foregroundColor: isDark ? Colors.grey[300] : null,
            ),
            child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(isEditing ? 'Atualizar' : 'Salvar',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)),
    );
  }

  static IconData _getIconeParaTipo(String tipo) {
    switch (tipo) {
      case 'viagem':
        return Icons.flight;
      case 'carro':
        return Icons.directions_car;
      case 'casa':
        return Icons.home;
      case 'estudo':
        return Icons.school;
      case 'investimento':
        return Icons.trending_up;
      default:
        return Icons.flag;
    }
  }
}

// 🔥 CLASSE AUXILIAR PARA INVESTIMENTO
class TipoInvestimento {
  static String getNomeAmigavel(String tipo) {
    switch (tipo) {
      case 'ACAO':
        return 'Ações';
      case 'FII':
        return 'FIIs';
      case 'CRIPTO':
        return 'Cripto';
      case 'RENDA_FIXA':
        return 'Renda Fixa';
      default:
        return tipo;
    }
  }

  static Color getCor(String tipo) {
    switch (tipo) {
      case 'ACAO':
        return Colors.blue;
      case 'FII':
        return Colors.green;
      case 'CRIPTO':
        return Colors.orange;
      case 'RENDA_FIXA':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
