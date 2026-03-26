// Crie um arquivo temporário: lib/utils/extract_proventos.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const dbPath =
      'C:\\Users\\anaep\\AppData\\Roaming\\com.example\\controle_financeiro_app\\financeiro.db';
  final db = await databaseFactory.openDatabase(dbPath);

  final proventos = await db.query('proventos');
  print('📊 Proventos encontrados: ${proventos.length}');

  for (var p in proventos) {
    print(p);
  }

  await db.close();
}
