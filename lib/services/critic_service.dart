import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'library_service.dart';

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

  int ratedEpisodeCountForShow(int showId) {
    return _ratedEpisodeCountsByShow[showId] ?? 0;
  }

  bool isLoading = false;

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

    _episodeRatings[_episodeKey(showId, seasonNumber, episodeNumber)] = rating;

    notifyListeners();

    await client.from('episode_ratings').upsert({
      'user_id': user.id,
      'show_id': showId,
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
      'rating': rating,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await refresh();
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

      // Recalculate counts, XP,
      // coverage, rated episodes, etc.
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

    isLoading = true;

    try {
      final results = await Future.wait([
        client
            .from('media_user_data')
            .select('tmdb_id, rating, media_type')
            .eq('user_id', user.id),

        client
            .from('episode_ratings')
            .select(
              'show_id, '
              'season_number, '
              'episode_number, '
              'rating',
            )
            .eq('user_id', user.id),

        client
            .from('music_user_data')
            .select('entity_type, rating, is_listened')
            .eq('user_id', user.id),
      ]);

      final movieRows = results[0];

      final episodeRows = results[1];

      final musicRows = results[2];

      final movieRatings = <int>[];

      final tvRatings = <int>[];

      final episodeRatings = <int>[];

      final albumRatings = <int>[];

      final songRatings = <int>[];

      _ratedMovieIds.clear();

      _titleRatings.clear();

      _ratedEpisodeCountsByShow.clear();

      for (final row in movieRows) {
        final rawRating = row['rating'];

        final rawTmdbId = row['tmdb_id'];

        final mediaType = row['media_type']?.toString();

        if (rawRating is! num) {
          continue;
        }

        final rating = rawRating.toInt();

        if (rawTmdbId is num && (mediaType == 'movie' || mediaType == 'tv')) {
          _titleRatings['$mediaType:${rawTmdbId.toInt()}'] = rating;
        }

        if (mediaType == 'movie') {
          movieRatings.add(rating);

          if (rawTmdbId is num) {
            _ratedMovieIds.add(rawTmdbId.toInt());
          }
        } else if (mediaType == 'tv') {
          tvRatings.add(rating);
        }
      }

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

      int listenedAlbumCount = 0;

      for (final row in musicRows) {
        final entityType = row['entity_type']?.toString();

        if (entityType == 'album' && row['is_listened'] == true) {
          listenedAlbumCount++;
        }

        final rawRating = row['rating'];
        if (rawRating is! num) {
          continue;
        }

        final rating = rawRating.toInt();

        if (entityType == 'album') {
          albumRatings.add(rating);
        } else if (entityType == 'track') {
          songRatings.add(rating);
        }
      }

      movieRatingCount = movieRatings.length;

      tvRatingCount = tvRatings.length;

      episodeRatingCount = episodeRatings.length;

      albumRatingCount = albumRatings.length;

      songRatingCount = songRatings.length;

      final allRatings = [
        ...movieRatings,
        ...tvRatings,
        ...episodeRatings,
        ...albumRatings,
        ...songRatings,
      ];

      totalRatings = allRatings.length;

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

      addRatingsToDistribution(allRatings, ratingDistribution);
      addRatingsToDistribution(movieRatings, movieRatingDistribution);
      addRatingsToDistribution(tvRatings, tvRatingDistribution);
      addRatingsToDistribution(episodeRatings, episodeRatingDistribution);
      addRatingsToDistribution(albumRatings, albumRatingDistribution);
      addRatingsToDistribution(songRatings, songRatingDistribution);

      if (allRatings.isEmpty) {
        averageStars = 0;
      } else {
        final int totalStars = allRatings.fold<int>(0, (sum, rating) {
          return sum + _storedRatingToStars(rating);
        });

        averageStars = totalStars / allRatings.length;
      }

      _calculateLevel();
      _calculateTitle();
      _calculateCoverage(listenedAlbums: listenedAlbumCount);
    } catch (e) {
      debugPrint('Could not refresh critic stats: $e');
    } finally {
      isLoading = false;

      notifyListeners();
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
