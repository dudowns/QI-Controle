// lib/utils/validators_br.dart
class ValidatorsBR {
  static bool isCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1*$').hasMatch(cpf)) return false;

    int calcDigit(String cpf, int factor) {
      int total = 0;
      for (int i = 0; i < factor - 1; i++) {
        total += int.parse(cpf[i]) * (factor - i);
      }
      int resto = total % 11;
      return resto < 2 ? 0 : 11 - resto;
    }

    int digit1 = calcDigit(cpf, 10);
    int digit2 = calcDigit(cpf, 11);

    return int.parse(cpf[9]) == digit1 && int.parse(cpf[10]) == digit2;
  }

  static bool isCNPJ(String cnpj) {
    cnpj = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (cnpj.length != 14) return false;
    if (RegExp(r'^(\d)\1*$').hasMatch(cnpj)) return false;

    int calcDigit(String cnpj, List<int> pesos) {
      int total = 0;
      for (int i = 0; i < pesos.length; i++) {
        total += int.parse(cnpj[i]) * pesos[i];
      }
      int resto = total % 11;
      return resto < 2 ? 0 : 11 - resto;
    }

    List<int> pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    List<int> pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

    int digit1 = calcDigit(cnpj, pesos1);
    int digit2 = calcDigit(cnpj, pesos2);

    return int.parse(cnpj[12]) == digit1 && int.parse(cnpj[13]) == digit2;
  }

  static String formatCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpf.length == 11) {
      return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}';
    }
    return cpf;
  }

  static String formatCNPJ(String cnpj) {
    cnpj = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (cnpj.length == 14) {
      return '${cnpj.substring(0, 2)}.${cnpj.substring(2, 5)}.${cnpj.substring(5, 8)}/${cnpj.substring(8, 12)}-${cnpj.substring(12)}';
    }
    return cnpj;
  }

  static String validateCPF(String? value) {
    if (value == null || value.isEmpty) return 'Digite o CPF';
    if (!isCPF(value)) return 'CPF inválido';
    return '';
  }

  static String validateCNPJ(String? value) {
    if (value == null || value.isEmpty) return 'Digite o CNPJ';
    if (!isCNPJ(value)) return 'CNPJ inválido';
    return '';
  }

  static String validateDocument(String? value) {
    if (value == null || value.isEmpty) return 'Digite o documento';
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 11) {
      return isCPF(clean) ? '' : 'CPF inválido';
    } else if (clean.length == 14) {
      return isCNPJ(clean) ? '' : 'CNPJ inválido';
    }
    return 'Documento inválido';
  }
}
