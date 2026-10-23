import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'library_service.dart';
import 'cloud_sync_service.dart';

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
    return const MediaUserData(isFavorite: false, rating: null, review: '');
  }
}

class MediaUserDataService extends ChangeNotifier {
  MediaUserDataService._();

  static final MediaUserDataService instance = MediaUserDataService._();

  final Set<String> _favoriteKeys = {};

  SupabaseClient get client => Supabase.instance.client;

  final Map<String, MediaUserData> _cache = {};

  String _key(int tmdbId, String mediaType) {
    return '$mediaType:$tmdbId';
  }

  MediaUserData getCached(int tmdbId, String mediaType) {
    return _cache[_key(tmdbId, mediaType)] ?? MediaUserData.empty();
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

      _favoriteKeys.add('$mediaType:$tmdbId');
    }

    notifyListeners();
  }

  bool isFavorite(int tmdbId, String mediaType) {
    return _favoriteKeys.contains('$mediaType:$tmdbId');
  }

  Future<MediaUserData> load(int tmdbId, String mediaType) async {
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
            isFavorite: data['is_favorite'] ?? false,
            rating: data['rating'],
            review: data['review'] ?? '',
          );

    _cache[_key(tmdbId, mediaType)] = result;

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
      throw Exception('You must be signed in.');
    }

    if (rating != null) {
      // The server trigger only accepts title ratings for a completed movie
      // or TV series. Ensure the current completed row has reached Supabase
      // before sending the rating (Library sync is normally debounced).
      final item = LibraryService.instance.getItem(tmdbId, mediaType);
      final completed = item?.status == 'completed';
      final inProgressTv = mediaType == 'tv' && item?.status == 'watching';
      if (item == null || (!completed && !inProgressTv)) {
        throw StateError('Watch this title before rating it.');
      }
      // An in-progress show may be rated once an actual episode is watched.
      // Its local episode state can also be ahead of the debounced cloud sync.
      if (inProgressTv) {
        final firstWatched = LibraryService.instance.firstWatchedEpisodeForShow(tmdbId);
        if (firstWatched == null) {
          throw StateError('Watch at least one episode before rating this show.');
        }
        await CloudSyncService.instance.ensureWatchedEpisode(
          userId: user.id,
          showId: firstWatched['showId']!,
          seasonNumber: firstWatched['seasonNumber']!,
          episodeNumber: firstWatched['episodeNumber']!,
          runtimeMinutes: firstWatched['runtimeMinutes'] ?? 0,
        );
      }
      await CloudSyncService.instance.uploadLibraryChanges(
        userId: user.id,
        upserts: [item.toJson()],
        deletes: const [],
      );
      if (client.auth.currentUser?.id != user.id ||
          LibraryService.instance.getItem(tmdbId, mediaType)?.status != item.status) {
        throw StateError('Account or watched state changed before rating.');
      }
    }

    await client.from('media_user_data').upsert({
      'user_id': user.id,
      'tmdb_id': tmdbId,
      'media_type': mediaType,
      'is_favorite': isFavorite,
      'rating': rating,
      'review': review.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    _cache[_key(tmdbId, mediaType)] = MediaUserData(
      isFavorite: isFavorite,
      rating: rating,
      review: review.trim(),
    );

    final favoriteKey = '$mediaType:$tmdbId';

    if (isFavorite) {
      _favoriteKeys.add(favoriteKey);
    } else {
      _favoriteKeys.remove(favoriteKey);
    }

    notifyListeners();
  }

  Future<void> toggleFavorite(int tmdbId, String mediaType) async {
    final current = getCached(tmdbId, mediaType);

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
