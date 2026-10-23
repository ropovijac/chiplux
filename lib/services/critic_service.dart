import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'library_service.dart';
import 'cloud_sync_service.dart';

// The compact server snapshot contains all the rated movie/episode IDs needed
// by Library badges, but only aggregate buckets for music. This avoids
// downloading the entire music_user_data table to calculate Critic statistics.
class _CriticRatingSnapshot {
  const _CriticRatingSnapshot({
    required this.mediaRows,
    required this.episodeRows,
    required this.albumHistogram,
    required this.songHistogram,
    required this.listenedAlbumCount,
  });

  final List<Map<String, dynamic>> mediaRows;
  final List<Map<String, dynamic>> episodeRows;
  // Index 0 = 1 star, index 4 = 5 stars.
  final List<int> albumHistogram;
  final List<int> songHistogram;
  final int listenedAlbumCount;

  static List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) {
      throw const FormatException('Expected Critic rating detail rows.');
    }
    return value.map((row) {
      if (row is! Map) {
        throw const FormatException('Invalid Critic rating detail row.');
      }
      return Map<String, dynamic>.from(row);
    }).toList(growable: false);
  }

  static List<int> _histogram(Object? value) {
    if (value is! List || value.length != 5 ||
        value.any((entry) => entry is! num)) {
      throw const FormatException('Invalid Critic rating distribution.');
    }
    return value.map((entry) => (entry as num).toInt())
        .toList(growable: false);
  }

  factory _CriticRatingSnapshot.fromRpc(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid Critic snapshot response.');
    }
    final data = Map<String, dynamic>.from(raw);
    if (data['version'] != 1 || data['music'] is! Map) {
      throw const FormatException('Unsupported Critic snapshot version.');
    }
    final music = Map<String, dynamic>.from(data['music'] as Map);
    final listened = music['listened_albums'];
    if (listened is! num || listened < 0) {
      throw const FormatException('Invalid listened album count.');
    }
    return _CriticRatingSnapshot(
      mediaRows: _rows(data['media_ratings']),
      episodeRows: _rows(data['episode_ratings']),
      albumHistogram: _histogram(music['album_histogram']),
      songHistogram: _histogram(music['song_histogram']),
      listenedAlbumCount: listened.toInt(),
    );
  }
}

class CriticService extends ChangeNotifier {
  CriticService._();

  static final CriticService instance = CriticService._();

  SupabaseClient get client => Supabase.instance.client;

  final Map<String, int> _episodeRatings = {};

  final Set<int> _ratedMovieIds = {};

  final Map<int, int> _ratedEpisodeCountsByShow = {};

  final Map<String, int> _titleRatings = {};

  bool isMovieRated(int movieId) {
    return _ratedMovieIds.contains(movieId);
  }

  int? titleRatingStars(int tmdbId, String mediaType) {
    final rating = _titleRatings['$mediaType:$tmdbId'];

    if (rating == null) {
      return null;
    }

    return _storedRatingToStars(rating);
  }

  Future<void> clearEpisodeAfterUnwatch({
    required int showId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return;
    }

    await client
        .from('episode_ratings')
        .delete()
        .eq('user_id', user.id)
        .eq('show_id', showId)
        .eq('season_number', seasonNumber)
        .eq('episode_number', episodeNumber);

    // If this was the last watched
    // episode, the show itself is no
    // longer considered watched either.
    if (LibraryService.instance.watchedCountForShow(showId) == 0) {
      await client
          .from('media_user_data')
          .update({'rating': null})
          .eq('user_id', user.id)
          .eq('tmdb_id', showId)
          .eq('media_type', 'tv');
    }

    await refresh();
    await reconcileTvRating(showId);
    await refresh();
  }

  Future<void> clearSeasonAfterUnwatch({
    required int showId,
    required int seasonNumber,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return;
    }

    await client
        .from('episode_ratings')
        .delete()
        .eq('user_id', user.id)
        .eq('show_id', showId)
        .eq('season_number', seasonNumber);

    if (LibraryService.instance.watchedCountForShow(showId) == 0) {
      await client
          .from('media_user_data')
          .update({'rating': null})
          .eq('user_id', user.id)
          .eq('tmdb_id', showId)
          .eq('media_type', 'tv');
    }

    await refresh();
    await reconcileTvRating(showId);
    await refresh();
  }

  Future<void> clearAllRatingsForRemovedMedia({
    required int tmdbId,
    required String mediaType,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return;
    }

    // Keep favorites/review.
    // Only reset the rating column.
    await client
        .from('media_user_data')
        .update({'rating': null})
        .eq('user_id', user.id)
        .eq('tmdb_id', tmdbId)
        .eq('media_type', mediaType);

    if (mediaType == 'tv') {
      await client
          .from('episode_ratings')
          .delete()
          .eq('user_id', user.id)
          .eq('show_id', tmdbId);
    }

    await refresh();
  }

  // A series has one derived rating only after every regular episode has a
  // saved rating. Season 0 specials never count toward completion.
  double? tvShowAverageStars(int showId) {
    final total = LibraryService.instance.getItem(showId, 'tv')?.totalEpisodes ?? 0;
    if (total <= 0) return null;
    final prefix = '$showId:';
    final ratings = <int>[];
    for (final entry in _episodeRatings.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final components = entry.key.split(':');
      if (components.length == 3 && int.tryParse(components[1]) != null &&
          int.parse(components[1]) > 0) {
        ratings.add(entry.value);
      }
    }
    if (ratings.length != total) return null;
    return ratings.reduce((a, b) => a + b) / (ratings.length * 2.0);
  }

  // Keep the existing title-rating row (used by stats, achievements and
  // profiles) synchronized with the computed episode average. Never change
  // favorite/review data. One stored 10-point unit represents half a star.
  Future<void> reconcileTvRating(int showId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final average = tvShowAverageStars(showId);
    final int? stored = average == null ? null : (average * 2).round().clamp(1, 10).toInt();
    final existing = await client.from('media_user_data')
        .select('rating,is_favorite,review')
        .eq('user_id', userId).eq('tmdb_id', showId)
        .eq('media_type', 'tv').maybeSingle();
    if (client.auth.currentUser?.id != userId) return;
    final old = existing?['rating'];
    if ((old is num ? old.toInt() : null) == stored) return;
    if (existing == null && stored == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    // Update JUST the aggregate rating so a concurrent favorite or review
    // edit cannot be accidentally reverted by a stale aggregate read.
    if (existing != null) {
      await client.from('media_user_data')
          .update({'rating': stored, 'updated_at': now})
          .eq('user_id', userId).eq('tmdb_id', showId)
          .eq('media_type', 'tv');
    } else {
      await client.from('media_user_data').upsert({
        'user_id': userId, 'tmdb_id': showId, 'media_type': 'tv',
        'rating': stored, 'is_favorite': false, 'review': '',
        'updated_at': now,
      }, onConflict: 'user_id,tmdb_id,media_type');
    }
  }

  int ratedEpisodeCountForShow(int showId) {
    return _ratedEpisodeCountsByShow[showId] ?? 0;
  }

  bool isLoading = false;
  int _refreshRequest = 0;

  // Fallback for projects that have not installed the Phase 5B SQL yet, or
  // when the RPC is temporarily unavailable. Keep the original correctness
  // behavior (including pagination and account-change safety).
  Future<List<Map<String, dynamic>>> _loadMusicRatingRows(String userId) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += pageSize) {
      final page = await client.from('music_user_data')
          .select('entity_type, entity_id, rating, is_listened')
          .eq('user_id', userId)
          .order('entity_type')
          .order('entity_id')
          .range(offset, offset + pageSize - 1);
      if (client.auth.currentUser?.id != userId) return [];
      rows.addAll(page.map((row) => Map<String, dynamic>.from(row)));
      if (page.length < pageSize) break;
    }
    return rows;
  }

  Future<_CriticRatingSnapshot> _legacyRatingSnapshot(String userId) async {
    final results = await Future.wait([
      client.from('media_user_data')
          .select('tmdb_id, rating, media_type').eq('user_id', userId),
      client.from('episode_ratings')
          .select('show_id, season_number, episode_number, rating')
          .eq('user_id', userId),
      _loadMusicRatingRows(userId),
    ]);
    final albumHistogram = List<int>.filled(5, 0);
    final songHistogram = List<int>.filled(5, 0);
    var listenedAlbumCount = 0;
    for (final row in results[2]) {
      final type = row['entity_type']?.toString();
      if (type == 'album' && row['is_listened'] == true) {
        listenedAlbumCount++;
      }
      final rating = row['rating'];
      if (rating is! num) continue;
      final stars = _storedRatingToStars(rating.toInt());
      if (type == 'album') {
        albumHistogram[stars - 1]++;
      } else if (type == 'track') {
        songHistogram[stars - 1]++;
      }
    }
    return _CriticRatingSnapshot(
      mediaRows: (results[0] as List).map((row) =>
          Map<String, dynamic>.from(row as Map)).toList(),
      episodeRows: (results[1] as List).map((row) =>
          Map<String, dynamic>.from(row as Map)).toList(),
      albumHistogram: albumHistogram,
      songHistogram: songHistogram,
      listenedAlbumCount: listenedAlbumCount,
    );
  }

  Future<_CriticRatingSnapshot> _loadRatingSnapshot(String userId) async {
    try {
      // Aggregated music statistics never cross the network as individual
      // rating rows. A single RPC also returns the compact movie/episode
      // rating keys needed by Discover, Library, and episode screens.
      final raw = await client.rpc('chiplux_critic_snapshot');
      if (client.auth.currentUser?.id != userId) {
        throw StateError('Critic account changed during refresh.');
      }
      return _CriticRatingSnapshot.fromRpc(raw);
    } catch (error) {
      if (client.auth.currentUser?.id != userId) rethrow;
      debugPrint('Critic snapshot unavailable; using existing queries: $error');
      return _legacyRatingSnapshot(userId);
    }
  }

  int totalXp = 0;

  int totalRatings = 0;

  int movieRatingCount = 0;
  int tvRatingCount = 0;
  int episodeRatingCount = 0;
  int albumRatingCount = 0;
  int songRatingCount = 0;

  double averageStars = 0;

  double titleRatingCoverage = 0;
  double episodeRatingCoverage = 0;

  int level = 1;
  int xpInLevel = 0;
  int requiredXp = 10;

  String title = 'NEW CRITIC';

  String _episodeKey(int showId, int seasonNumber, int episodeNumber) {
    return '$showId:$seasonNumber:$episodeNumber';
  }

  int _storedRatingToStars(int rating) {
    return (rating / 2).round().clamp(1, 5).toInt();
  }

  int? getEpisodeRating(int showId, int seasonNumber, int episodeNumber) {
    return _episodeRatings[_episodeKey(showId, seasonNumber, episodeNumber)];
  }

  Future<int?> loadEpisodeRating(
    int showId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final data = await client
        .from('episode_ratings')
        .select('rating')
        .eq('user_id', user.id)
        .eq('show_id', showId)
        .eq('season_number', seasonNumber)
        .eq('episode_number', episodeNumber)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    final rawRating = data['rating'];

    if (rawRating is! num) {
      return null;
    }

    final rating = rawRating.toInt();

    _episodeRatings[_episodeKey(showId, seasonNumber, episodeNumber)] = rating;

    return rating;
  }

  final Map<int, int> ratingDistribution = {for (int i = 1; i <= 5; i++) i: 0};

  final Map<int, int> movieRatingDistribution = {
    for (int i = 1; i <= 5; i++) i: 0,
  };
  final Map<int, int> tvRatingDistribution = {
    for (int i = 1; i <= 5; i++) i: 0,
  };
  final Map<int, int> episodeRatingDistribution = {
    for (int i = 1; i <= 5; i++) i: 0,
  };
  final Map<int, int> albumRatingDistribution = {
    for (int i = 1; i <= 5; i++) i: 0,
  };
  final Map<int, int> songRatingDistribution = {
    for (int i = 1; i <= 5; i++) i: 0,
  };

  Map<int, int> distributionFor(String category) {
    switch (category) {
      case 'movies':
        return movieRatingDistribution;
      case 'tv':
        return tvRatingDistribution;
      case 'episodes':
        return episodeRatingDistribution;
      case 'albums':
        return albumRatingDistribution;
      case 'songs':
        return songRatingDistribution;
      case 'all':
      default:
        return ratingDistribution;
    }
  }

  Future<void> saveEpisodeRating({
    required int showId,
    required int seasonNumber,
    required int episodeNumber,
    required int rating,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final bool watched = LibraryService.instance.isEpisodeWatched(
      showId,
      seasonNumber,
      episodeNumber,
    );

    if (!watched) {
      throw Exception('Mark this episode as watched before rating it.');
    }

    // The database trigger checks the canonical watched_episodes table, not
    // the local SharedPreferences cache. Debounced Library sync can lag behind
    // a tap, so commit this specific watched row before the rating.
    await CloudSyncService.instance.ensureWatchedEpisode(
      userId: user.id,
      showId: showId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      runtimeMinutes: LibraryService.instance.episodeRuntimeMinutes(
        showId, seasonNumber, episodeNumber,
      ),
    );
    if (client.auth.currentUser?.id != user.id ||
        !LibraryService.instance.isEpisodeWatched(
          showId, seasonNumber, episodeNumber,
        )) {
      throw StateError('Account or watched state changed before rating.');
    }

    // Only update the in-memory rating after the server accepted the write.
    await client.from('episode_ratings').upsert({
      'user_id': user.id,
      'show_id': showId,
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
      'rating': rating,
      'updated_at': DateTime.now().toIso8601String(),
    });

    _episodeRatings[_episodeKey(showId, seasonNumber, episodeNumber)] = rating;
    notifyListeners();
    try {
      await refresh();
      await reconcileTvRating(showId);
      await refresh();
    } catch (error) {
      // The episode rating was saved; aggregate failure must not undo it.
      debugPrint('Critic statistics refresh failed after saved rating: $error');
    }
  }

  Future<void> removeEpisodeRating({
    required int showId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final key = _episodeKey(showId, seasonNumber, episodeNumber);

    final previousRating = _episodeRatings[key];

    // Update UI immediately.
    _episodeRatings.remove(key);

    notifyListeners();

    try {
      await client
          .from('episode_ratings')
          .delete()
          .eq('user_id', user.id)
          .eq('show_id', showId)
          .eq('season_number', seasonNumber)
          .eq('episode_number', episodeNumber);

      await refresh();
      await reconcileTvRating(showId);
      await refresh();
    } catch (e) {
      // Restore it if deletion failed.
      if (previousRating != null) {
        _episodeRatings[key] = previousRating;
      }

      notifyListeners();

      rethrow;
    }
  }

  Future<void> refresh() async {
    final user = client.auth.currentUser;

    if (user == null) {
      clear();
      return;
    }

    final request = ++_refreshRequest;
    isLoading = true;

    try {
      final snapshot = await _loadRatingSnapshot(user.id);
      final movieRows = snapshot.mediaRows;
      final episodeRows = snapshot.episodeRows;

      // Ignore an older refresh if another one began after a music save,
      // or if the signed-in account changed while this request was pending.
      if (request != _refreshRequest || client.auth.currentUser?.id != user.id) {
        return;
      }

      final movieRatings = <int>[];

      final tvRatings = <int>[];

      final episodeRatings = <int>[];

      _ratedMovieIds.clear();

      _titleRatings.clear();

      _ratedEpisodeCountsByShow.clear();

      _episodeRatings.clear();

      for (final row in episodeRows) {
        final rawShowId = row['show_id'];

        final rawSeason = row['season_number'];

        final rawEpisode = row['episode_number'];

        final rawRating = row['rating'];

        if (rawShowId is! num ||
            rawSeason is! num ||
            rawEpisode is! num ||
            rawRating is! num) {
          continue;
        }

        final rating = rawRating.toInt();

        episodeRatings.add(rating);

        _episodeRatings[_episodeKey(
              rawShowId.toInt(),
              rawSeason.toInt(),
              rawEpisode.toInt(),
            )] =
            rating;

        // Season 0 = specials.
        // Don't count specials toward
        // normal-series completion.
        if (rawSeason.toInt() > 0) {
          final showId = rawShowId.toInt();

          _ratedEpisodeCountsByShow[showId] =
              (_ratedEpisodeCountsByShow[showId] ?? 0) + 1;
        }
      }

      for (final row in movieRows) {
        final rawRating = row['rating'];
        final rawTmdbId = row['tmdb_id'];
        final mediaType = row['media_type']?.toString();
        if (mediaType != 'movie' || rawRating is! num) continue;
        final rating = rawRating.toInt();
        movieRatings.add(rating);
        if (rawTmdbId is num) {
          final id = rawTmdbId.toInt();
          _ratedMovieIds.add(id);
          _titleRatings['movie:$id'] = rating;
        }
      }

      // TV parent ratings are derived from episode rows, not trusted from
      // legacy manually entered media_user_data ratings. This also updates
      // Critic XP and rated-show achievements without needing to visit a
      // specific show page first.
      for (final showId in _ratedEpisodeCountsByShow.keys) {
        final average = tvShowAverageStars(showId);
        if (average == null) continue;
        final rating = (average * 2).round().clamp(1, 10).toInt();
        tvRatings.add(rating);
        _titleRatings['tv:$showId'] = rating;
      }

      final listenedAlbumCount = snapshot.listenedAlbumCount;

      movieRatingCount = movieRatings.length;

      tvRatingCount = tvRatings.length;

      episodeRatingCount = episodeRatings.length;

      albumRatingCount = snapshot.albumHistogram.fold<int>(
          0, (sum, count) => sum + count);
      songRatingCount = snapshot.songHistogram.fold<int>(
          0, (sum, count) => sum + count);

      totalRatings = movieRatingCount + tvRatingCount + episodeRatingCount +
          albumRatingCount + songRatingCount;

      // Keep the existing Chiplux weighting:
      // short-form items (episodes / songs) = 5 XP
      // long-form items (movies / TV titles / albums) = 10 XP
      totalXp =
          episodeRatingCount * 5 +
          songRatingCount * 5 +
          movieRatingCount * 10 +
          tvRatingCount * 10 +
          albumRatingCount * 10;

      for (int i = 1; i <= 5; i++) {
        ratingDistribution[i] = 0;
        movieRatingDistribution[i] = 0;
        tvRatingDistribution[i] = 0;
        episodeRatingDistribution[i] = 0;
        albumRatingDistribution[i] = 0;
        songRatingDistribution[i] = 0;
      }

      void addRatingsToDistribution(
        Iterable<int> ratings,
        Map<int, int> target,
      ) {
        for (final rating in ratings) {
          final int stars = _storedRatingToStars(rating);
          target[stars] = (target[stars] ?? 0) + 1;
        }
      }

      addRatingsToDistribution(movieRatings, movieRatingDistribution);
      addRatingsToDistribution(tvRatings, tvRatingDistribution);
      addRatingsToDistribution(episodeRatings, episodeRatingDistribution);

      // The server computes music histograms, but the resulting five buckets
      // are identical to the existing client-side rounded-star mapping.
      for (var i = 1; i <= 5; i++) {
        albumRatingDistribution[i] = snapshot.albumHistogram[i - 1];
        songRatingDistribution[i] = snapshot.songHistogram[i - 1];
        ratingDistribution[i] = (movieRatingDistribution[i] ?? 0) +
            (tvRatingDistribution[i] ?? 0) +
            (episodeRatingDistribution[i] ?? 0) +
            snapshot.albumHistogram[i - 1] +
            snapshot.songHistogram[i - 1];
      }

      if (totalRatings == 0) {
        averageStars = 0;
      } else {
        var totalStars = 0;
        for (var i = 1; i <= 5; i++) {
          totalStars += i * (ratingDistribution[i] ?? 0);
        }
        averageStars = totalStars / totalRatings;
      }

      _calculateLevel();
      _calculateTitle();
      _calculateCoverage(listenedAlbums: listenedAlbumCount);
    } catch (e) {
      debugPrint('Could not refresh critic stats: $e');
    } finally {
      if (request == _refreshRequest && client.auth.currentUser?.id == user.id) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void _calculateLevel() {
    level = 1;

    xpInLevel = totalXp;

    while (xpInLevel >= level * 10) {
      xpInLevel -= level * 10;

      level++;
    }

    requiredXp = level * 10;
  }

  void _calculateTitle() {
    if (totalRatings == 0) {
      title = 'NEW CRITIC';
      return;
    }

    if (averageStars < 1.5) {
      title = 'HARD TO IMPRESS';
    } else if (averageStars < 2.5) {
      title = 'SKEPTIC';
    } else if (averageStars < 3.5) {
      title = 'BALANCED CRITIC';
    } else if (averageStars < 4.25) {
      title = 'ENTHUSIAST';
    } else if (averageStars < 4.75) {
      title = 'ADMIRER';
    } else {
      title = 'SUPERFAN';
    }
  }

  void _calculateCoverage({required int listenedAlbums}) {
    final library = LibraryService.instance;

    // --------------------------------
    // LONG-FORM TITLES
    // TV shows, movies and listened albums
    // each count as one long-form title.
    // --------------------------------

    final int watchedTvShows = library.items.where((item) {
      if (item.mediaType != 'tv') {
        return false;
      }

      return item.status == 'completed' ||
          library.watchedCountForShow(item.id) > 0;
    }).length;

    final int watchedMovies = library.moviesWatchedCount;

    final int watchedTitles = watchedTvShows + watchedMovies + listenedAlbums;

    final int ratedTitles = tvRatingCount + movieRatingCount + albumRatingCount;

    if (watchedTitles <= 0) {
      titleRatingCoverage = 0.0;
    } else {
      titleRatingCoverage =
          (ratedTitles.toDouble() / watchedTitles.toDouble()) * 100.0;

      titleRatingCoverage = titleRatingCoverage.clamp(0.0, 100.0);
    }

    // --------------------------------
    // EPISODES
    // --------------------------------

    final int watchedEpisodes = library.watchedEpisodeCount;

    if (watchedEpisodes <= 0) {
      episodeRatingCoverage = 0.0;
    } else {
      episodeRatingCoverage =
          (episodeRatingCount.toDouble() / watchedEpisodes.toDouble()) * 100.0;

      episodeRatingCoverage = episodeRatingCoverage.clamp(0.0, 100.0);
    }
  }

  double ratingPercentage(int rating) {
    if (totalRatings <= 0) {
      return 0.0;
    }

    final int count = ratingDistribution[rating] ?? 0;

    return (count.toDouble() / totalRatings.toDouble()) * 100.0;
  }

  void clear() {
    _refreshRequest++;
    _episodeRatings.clear();
    _ratedMovieIds.clear();
    _titleRatings.clear();

    _ratedEpisodeCountsByShow.clear();

    isLoading = false;

    totalXp = 0;

    totalRatings = 0;

    movieRatingCount = 0;
    tvRatingCount = 0;
    episodeRatingCount = 0;
    albumRatingCount = 0;
    songRatingCount = 0;

    averageStars = 0;

    titleRatingCoverage = 0;
    episodeRatingCoverage = 0;

    level = 1;
    xpInLevel = 0;
    requiredXp = 10;

    title = 'NEW CRITIC';

    for (int i = 1; i <= 5; i++) {
      ratingDistribution[i] = 0;
      movieRatingDistribution[i] = 0;
      tvRatingDistribution[i] = 0;
      episodeRatingDistribution[i] = 0;
      albumRatingDistribution[i] = 0;
      songRatingDistribution[i] = 0;
    }

    notifyListeners();
  }
}
