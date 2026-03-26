// lib/utils/validators.dart
import '../constants/app_strings.dart';

class Validators {
  // Validação de valor monetário
  static String? validateValor(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite um valor';
    }

    // Remove R$ e espaços se tiver
    String cleaned = value.replaceAll('R\$', '').replaceAll(' ', '');
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');

    final valor = double.tryParse(cleaned);
    if (valor == null) {
      return 'Número inválido';
    }
    if (valor <= 0) {
      return 'Valor deve ser maior que zero';
    }
    if (valor > 999999999) {
      return 'Valor muito alto';
    }

    return null;
  }

  // Validação de descrição
  static String? validateDescricao(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite uma descrição';
    }
    if (value.length < 3) {
      return 'Mínimo 3 caracteres';
    }
    if (value.length > 100) {
      return 'Máximo 100 caracteres';
    }
    return null;
  }

  // Validação de ticker (ações, FIIs)
  static String? validateTicker(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite o ticker';
    }

    // Remove espaços e deixa maiúsculo
    final ticker = value.trim().toUpperCase();

    // Regex para ticker: letras e números, 4-6 caracteres
    final regex = RegExp(r'^[A-Z0-9]{4,6}$');
    if (!regex.hasMatch(ticker)) {
      return 'Ticker inválido (ex: PETR4, MXRF11)';
    }

    return null;
  }

  // Validação de quantidade
  static String? validateQuantidade(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite a quantidade';
    }

    final qtd = double.tryParse(value.replaceAll(',', '.'));
    if (qtd == null) {
      return 'Número inválido';
    }
    if (qtd <= 0) {
      return 'Quantidade deve ser maior que zero';
    }
    if (qtd > 1000000) {
      return 'Quantidade muito alta';
    }

    return null;
  }

  // Validação de data
  static String? validateData(DateTime? data) {
    if (data == null) {
      return 'Selecione uma data';
    }

    if (data.isAfter(DateTime.now().add(const Duration(days: 365)))) {
      return 'Data muito distante';
    }

    return null;
  }

  // Validação de email (para futuro)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email é opcional
    }

    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) {
      return 'Email inválido';
    }

    return null;
  }

  // Validação de telefone (para futuro)
  static String? validateTelefone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Telefone é opcional
    }

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10 || digits.length > 11) {
      return 'Telefone inválido';
    }

    return null;
  }

  // Validação de meta
  static String? validateMetaTitulo(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite o título da meta';
    }
    if (value.length < 3) {
      return 'Mínimo 3 caracteres';
    }
    return null;
  }
}
