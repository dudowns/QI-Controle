// lib/utils/fix_database_final.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('🔧 CORREÇÃO FINAL DO BANCO DE DADOS');
  print('=====================================');

  final appDir = await getApplicationSupportDirectory();
  final dbPath = join(appDir.path, 'financeiro.db');
  print('📁 Banco de dados: $dbPath');

  // 1. FAZER BACKUP DO BANCO ANTIGO
  final backupPath = join(appDir.path, 'financeiro_backup.db');
  try {
    final file = File(dbPath);
    if (await file.exists()) {
      await file.copy(backupPath);
      print('✅ Backup criado em: $backupPath');
    }
  } catch (e) {
    print('⚠️ Erro ao fazer backup: $e');
  }

  // 2. ABRIR BANCO
  final db = await databaseFactory.openDatabase(dbPath);

  // 3. LISTAR TODAS AS TABELAS
  final tables =
      await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");

  print('\n📊 TABELAS ENCONTRADAS:');
  for (var table in tables) {
    final tableName = table['name'] as String;
    print('   - $tableName');

    // Verificar estrutura atual
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    print('     Colunas: ${columns.map((c) => c['name']).join(', ')}');

    // 4. ADICIONAR COLUNAS FALTANTES
    if (tableName == 'proventos') {
      final hasUpdatedAt = columns.any((c) => c['name'] == 'updated_at');
      if (!hasUpdatedAt) {
        try {
          await db.execute(
              'ALTER TABLE proventos ADD COLUMN updated_at TEXT DEFAULT CURRENT_TIMESTAMP');
          print('   ✅ Coluna updated_at ADICIONADA em proventos!');
        } catch (e) {
          print('   ❌ Erro: $e');
        }
      } else {
        print('   ⏭️ Coluna updated_at já existe');
      }
    }

    if (tableName == 'lancamentos') {
      final hasCreatedAt = columns.any((c) => c['name'] == 'created_at');
      final hasUpdatedAt = columns.any((c) => c['name'] == 'updated_at');

      if (!hasCreatedAt) {
        try {
          await db.execute(
              'ALTER TABLE lancamentos ADD COLUMN created_at TEXT DEFAULT CURRENT_TIMESTAMP');
          print('   ✅ Coluna created_at ADICIONADA em lancamentos!');
        } catch (e) {}
      }
      if (!hasUpdatedAt) {
        try {
          await db.execute(
              'ALTER TABLE lancamentos ADD COLUMN updated_at TEXT DEFAULT CURRENT_TIMESTAMP');
          print('   ✅ Coluna updated_at ADICIONADA em lancamentos!');
        } catch (e) {}
      }
    }
  }

  // 5. VERIFICAR NOVAMENTE
  print('\n🔍 VERIFICAÇÃO FINAL:');
  final proventosCols = await db.rawQuery('PRAGMA table_info(proventos)');
  final hasUpdatedNow = proventosCols.any((c) => c['name'] == 'updated_at');
  print('📌 proventos.updated_at existe: $hasUpdatedNow');

  await db.close();

  if (!hasUpdatedNow) {
    print('\n❌ AINDA NÃO FUNCIONOU! Vamos apagar e recriar...');

    // 6. SE NÃO FUNCIONOU, APAGAR E RECRIAR
    await db.close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
      print('🗑️ Banco antigo apagado!');
    }

    print('✅ Agora rode o app novamente para criar o banco novo!');
  } else {
    print('\n✅ TUDO CERTO! Banco corrigido com sucesso!');
  }
}
