import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaUserData {
  final bool isFavorite;
  final int? rating;
  final String review;

  const MediaUserData({
    required this.isFavorite,
    required this.rating,
    required this.review,
  });

  factory MediaUserData.empty() {
    return const MediaUserData(
      isFavorite: false,
      rating: null,
      review: '',
    );
  }
}

class MediaUserDataService extends ChangeNotifier {
  MediaUserDataService._();

  static final MediaUserDataService instance =
      MediaUserDataService._();

      final Set<String> _favoriteKeys = {};

  SupabaseClient get client =>
      Supabase.instance.client;

  final Map<String, MediaUserData> _cache = {};

  String _key(
    int tmdbId,
    String mediaType,
  ) {
    return '$mediaType:$tmdbId';
  }

  MediaUserData getCached(
    int tmdbId,
    String mediaType,
  ) {
    return _cache[
            _key(tmdbId, mediaType)] ??
        MediaUserData.empty();
  }

  Future<void> loadFavorites() async {
  final user = client.auth.currentUser;

  if (user == null) {
    _favoriteKeys.clear();
    notifyListeners();
    return;
  }

  final data = await client
      .from('media_user_data')
      .select('tmdb_id, media_type')
      .eq('user_id', user.id)
      .eq('is_favorite', true);

  _favoriteKeys.clear();

  for (final item in data) {
    final tmdbId = item['tmdb_id'];
    final mediaType = item['media_type'];

    _favoriteKeys.add(
      '$mediaType:$tmdbId',
    );
  }

  notifyListeners();
}

bool isFavorite(
  int tmdbId,
  String mediaType,
) {
  return _favoriteKeys.contains(
    '$mediaType:$tmdbId',
  );
}

  Future<MediaUserData> load(
    int tmdbId,
    String mediaType,
  ) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return MediaUserData.empty();
    }

    final data = await client
        .from('media_user_data')
        .select()
        .eq('user_id', user.id)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', mediaType)
        .maybeSingle();

    final result = data == null
        ? MediaUserData.empty()
        : MediaUserData(
            isFavorite:
                data['is_favorite'] ?? false,
            rating: data['rating'],
            review:
                data['review'] ?? '',
          );

    _cache[_key(
      tmdbId,
      mediaType,
    )] = result;

    notifyListeners();

    return result;
  }

  Future<void> save({
    required int tmdbId,
    required String mediaType,
    required bool isFavorite,
    required int? rating,
    required String review,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be signed in.',
      );
    }

    await client
        .from('media_user_data')
        .upsert({
      'user_id': user.id,
      'tmdb_id': tmdbId,
      'media_type': mediaType,
      'is_favorite': isFavorite,
      'rating': rating,
      'review': review.trim(),
      'updated_at':
          DateTime.now().toIso8601String(),
    });

    _cache[_key(
      tmdbId,
      mediaType,
    )] = MediaUserData(
      isFavorite: isFavorite,
      rating: rating,
      review: review.trim(),
    );

    final favoriteKey =
    '$mediaType:$tmdbId';

if (isFavorite) {
  _favoriteKeys.add(favoriteKey);
} else {
  _favoriteKeys.remove(favoriteKey);
}

    notifyListeners();
  }

  Future<void> toggleFavorite(
    int tmdbId,
    String mediaType,
  ) async {
    final current =
        getCached(tmdbId, mediaType);

    await save(
      tmdbId: tmdbId,
      mediaType: mediaType,
      isFavorite: !current.isFavorite,
      rating: current.rating,
      review: current.review,
    );
  }

  void clearCache() {
  _cache.clear();
  _favoriteKeys.clear();
  notifyListeners();
}
}