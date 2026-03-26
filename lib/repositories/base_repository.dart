// lib/repositories/base_repository.dart

import '../database/db_helper.dart';

abstract class BaseRepository<T> {
  final DBHelper dbHelper = DBHelper();

  Future<int> insert(T item);
  Future<int> update(T item);
  Future<int> delete(int id);
  Future<T?> getById(int id);
  Future<List<T>> getAll();
  String get tableName;
  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T item);
}
