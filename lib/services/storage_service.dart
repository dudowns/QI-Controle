// lib/services/storage_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final _supabase = Supabase.instance.client;

  Future<File?> pickImage() async {
    try {
      // ✅ API CORRETA PARA TODAS AS VERSÕES DO file_picker
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) return File(path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadProfilePhoto(File file, String userId) async {
    try {
      final fileExt = file.path.split('.').last;
      final fileName =
          '$userId.${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      await _supabase.storage
          .from('profiles')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      final url = _supabase.storage.from('profiles').getPublicUrl(filePath);

      await _supabase
          .from('profiles')
          .update({'avatar_url': url}).eq('id', userId);

      return url;
    } catch (e) {
      return null;
    }
  }

  String? getProfilePhoto(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    return avatarUrl;
  }
}
