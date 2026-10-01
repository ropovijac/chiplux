import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarService {
  AvatarService._();

  static final AvatarService instance = AvatarService._();

  SupabaseClient get client => Supabase.instance.client;

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final path = '${user.id}/avatar.$extension';

    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = client.storage.from('avatars').getPublicUrl(path);

    return publicUrl;
  }
}
