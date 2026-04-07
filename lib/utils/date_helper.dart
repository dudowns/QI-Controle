// lib/utils/date_helper.dart
import 'package:intl/intl.dart';

class DateHelper {
  // Retorna o horário atual de Brasília (UTC-3)
  static DateTime agoraBrasilia() {
    final agoraUtc = DateTime.now().toUtc();
    // Brasil = UTC-3 (durante o ano todo, sem horário de verão)
    return agoraUtc.add(const Duration(hours: -3));
  }

  // Converte UTC para Brasília (para exibição)
  static DateTime utcParaBrasilia(DateTime utc) {
    // Garantir que está em UTC e converter para Brasília
    final utcDate = DateTime.utc(utc.year, utc.month, utc.day, utc.hour,
        utc.minute, utc.second, utc.millisecond, utc.microsecond);
    return utcDate.add(const Duration(hours: -3));
  }

  // Converte hora local (do sistema) para UTC (para salvar)
  static DateTime localParaUtc(DateTime local) {
    return local.toUtc();
  }

  // Formata data no padrão brasileiro
  static String formatarDataBrasil(DateTime data, {bool comHora = false}) {
    final dataBrasilia = utcParaBrasilia(data);
    if (comHora) {
      return DateFormat('dd/MM/yyyy HH:mm').format(dataBrasilia);
    }
    return DateFormat('dd/MM/yyyy').format(dataBrasilia);
  }

  // Verifica se é hoje (considerando Brasília)
  static bool ehHoje(DateTime data) {
    final dataBrasilia = utcParaBrasilia(data);
    final hoje = agoraBrasilia();
    return dataBrasilia.year == hoje.year &&
        dataBrasilia.month == hoje.month &&
        dataBrasilia.day == hoje.day;
  }

  // Retorna dias atrás (para o lembrete)
  static int diasAtras(DateTime data) {
    final dataBrasilia = utcParaBrasilia(data);
    final hoje = agoraBrasilia();
    return hoje.difference(dataBrasilia).inDays;
  }

  // Extrair data do nome do arquivo (mais preciso)
  static DateTime? dataDoNomeArquivo(String nomeArquivo) {
    final regex = RegExp(r'backup_(\d+)\.json');
    final match = regex.firstMatch(nomeArquivo);

    if (match != null) {
      final timestamp = int.parse(match.group(1)!);
      // O timestamp já está em Brasília (pois salvamos assim)
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }
}

