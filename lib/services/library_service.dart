import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_service.dart';
import 'tmdb_service.dart';
import 'community_service.dart';

class LibraryItem {
  final int id;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String year;
  final String status;
  final int totalEpisodes;
  final int runtimeMinutes;
  final List<int> genreIds;
  final int addedAt;

  const LibraryItem({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.year,
    required this.status,
    required this.totalEpisodes,
    this.runtimeMinutes = 0,
    this.genreIds = const [],
    required this.addedAt,
  });

  String get uniqueKey =>
      '$mediaType:$id';

  LibraryItem copyWith({
    String? status,
    int? totalEpisodes,
    int? runtimeMinutes,
    List<int>? genreIds,
    int? addedAt,
  }) {
    return LibraryItem(
      id: id,
      mediaType: mediaType,
      title: title,
      posterPath: posterPath,
      year: year,
      status:
          status ?? this.status,
      totalEpisodes:
          totalEpisodes ??
              this.totalEpisodes,
      runtimeMinutes:
          runtimeMinutes ??
              this.runtimeMinutes,
      genreIds:
          genreIds ??
              this.genreIds,
      addedAt:
          addedAt ??
              this.addedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaType': mediaType,
      'title': title,
      'posterPath': posterPath,
      'year': year,
      'status': status,
      'totalEpisodes':
          totalEpisodes,
      'runtimeMinutes':
          runtimeMinutes,
      'genreIds':
          genreIds,
      'addedAt':
          addedAt,
    };
  }

  factory LibraryItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return LibraryItem(
      id:
          (json['id'] as num)
              .toInt(),
      mediaType:
          json['mediaType']
              .toString(),
      title:
          json['title'] ??
              'Unknown',
      posterPath:
          json['posterPath'],
      year:
          json['year'] ?? '',
      status:
          json['status'] ??
              'plan',
      totalEpisodes:
          json['totalEpisodes']
                  is num
              ? (json[
                          'totalEpisodes']
                      as num)
                  .toInt()
              : 0,
      runtimeMinutes:
          json['runtimeMinutes']
                  is num
              ? (json[
                          'runtimeMinutes']
                      as num)
                  .toInt()
              : json[
                          'runtime_minutes']
                      is num
                  ? (json[
                              'runtime_minutes']
                          as num)
                      .toInt()
                  : 0,
      genreIds:
          List<int>.from(
        (
          json['genreIds'] ??
              json['genre_ids'] ??
              const <dynamic>[]
        ).map(
          (value) =>
              (value as num)
                  .toInt(),
        ),
      ),
      addedAt:
          json['addedAt']
                  is num
              ? (json['addedAt']
                      as num)
                  .toInt()
              : DateTime.now()
                  .millisecondsSinceEpoch,
    );
  }
}

class LibraryService
    extends ChangeNotifier {
  LibraryService._();

  static final LibraryService instance =
      LibraryService._();

  static const String _libraryKey =
      'chiplux_library_v2';

  static const String _episodesKey =
      'chiplux_watched_episodes_v2';

  static const String
      _episodeRuntimesKey =
      'chiplux_watched_episode_runtimes_v1';

  final List<LibraryItem>
      _items = [];

  final Set<String>
      _watchedEpisodes = {};

  final Map<String, int>
      _watchedEpisodeRuntimes =
      {};

  // Existing 500ms debounce.
  Timer? _cloudSyncTimer;

  // Prevent two actual cloud syncs
  // from running at the same time.
  Future<void>? _activeCloudSync;

  bool _cloudSyncRequested =
      false;

  // Changes whenever the entire local
  // account state is replaced/cleared.
  //
  // This prevents an old async TMDB task
  // from modifying a newly signed-in
  // account's data.
  int _stateGeneration = 0;

  // Prevent duplicate background jobs
  // for the same completed TV show.
  final Set<int>
      _finishingTvShows = {};

  List<LibraryItem> get items =>
      List.unmodifiable(
        _items,
      );

  int get watchedEpisodeCount =>
      _watchedEpisodes.length;

  int get moviesWatchedCount =>
      _items.where(
        (item) =>
            item.mediaType ==
                'movie' &&
            item.status ==
                'completed',
      ).length;

      int get completedTvShowsCount =>
    _items.where(
      (item) =>
          item.mediaType == 'tv' &&
          item.status == 'completed',
    ).length;

  int get completedCount =>
      _items.where(
        (item) =>
            item.status ==
                'completed',
      ).length;

     int get watchedEpisodeMinutes {
  int total = 0;

  for (final key in _watchedEpisodes) {
    total +=
        _watchedEpisodeRuntimes[key] ??
            0;
  }

  return total;
}

int get watchedMovieMinutes {
  int total = 0;

  for (final item in _items) {
    if (item.mediaType == 'movie' &&
        item.status == 'completed') {
      total += item.runtimeMinutes;
    }
  }

  return total;
} 

  int get totalWatchedMinutes {
    int total = 0;

    for (final key
        in _watchedEpisodes) {
      total +=
          _watchedEpisodeRuntimes[
                  key] ??
              0;
    }

    for (final item
        in _items) {
      if (item.mediaType ==
              'movie' &&
          item.status ==
              'completed') {
        total +=
            item.runtimeMinutes;
      }
    }

    return total;
  }

  int watchedMinutesForItem(
    LibraryItem item,
  ) {
    if (item.mediaType ==
        'movie') {
      if (item.status !=
          'completed') {
        return 0;
      }

      return item.runtimeMinutes;
    }

    if (item.mediaType ==
        'tv') {
      int total = 0;

      for (final key
          in _watchedEpisodes) {
        if (key.startsWith(
          '${item.id}:',
        )) {
          total +=
              _watchedEpisodeRuntimes[
                      key] ??
                  0;
        }
      }

      return total;
    }

    return 0;
  }

  // =====================================================
  // INITIALIZATION
  // =====================================================

  Future<void> init() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final libraryJson =
        prefs.getString(
      _libraryKey,
    );

    if (libraryJson != null) {
      final List<dynamic>
          decoded =
          jsonDecode(
        libraryJson,
      );

      _items
        ..clear()
        ..addAll(
          decoded.map(
            (item) =>
                LibraryItem
                    .fromJson(
              Map<String, dynamic>
                  .from(
                item,
              ),
            ),
          ),
        );
    }

    final runtimesJson =
        prefs.getString(
      _episodeRuntimesKey,
    );

    if (runtimesJson !=
        null) {
      final decoded =
          Map<String, dynamic>
              .from(
        jsonDecode(
          runtimesJson,
        ),
      );

      _watchedEpisodeRuntimes
        ..clear()
        ..addAll(
          decoded.map(
            (
              key,
              value,
            ) =>
                MapEntry(
              key,
              (value as num)
                  .toInt(),
            ),
          ),
        );
    }

    final watched =
        prefs.getStringList(
      _episodesKey,
    );

    if (watched != null) {
      _watchedEpisodes
        ..clear()
        ..addAll(
          watched,
        );
    }
  }

  // =====================================================
  // LOCAL SAVING
  // =====================================================

  Future<void>
      _saveLibrary() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      _libraryKey,
      jsonEncode(
        _items
            .map(
              (item) =>
                  item.toJson(),
            )
            .toList(),
      ),
    );
  }

  Future<void>
      _saveEpisodes() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setStringList(
      _episodesKey,
      _watchedEpisodes
          .toList(),
    );
  }

  Future<void>
      _saveEpisodeRuntimes()
      async {
    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      _episodeRuntimesKey,
      jsonEncode(
        _watchedEpisodeRuntimes,
      ),
    );
  }

  // =====================================================
  // DEBOUNCED CLOUD SYNC
  // =====================================================

  void _scheduleCloudSync() {
    _cloudSyncTimer?.cancel();

    _cloudSyncTimer = Timer(
      const Duration(
        milliseconds: 500,
      ),
      () async {
        _cloudSyncTimer =
            null;

        try {
          await syncToCloud();
        } catch (e) {
          debugPrint(
            'Background cloud sync failed: $e',
          );
        }
      },
    );
  }

  // =====================================================
  // COMPLETED TV SHOW BACKGROUND PROCESS
  // =====================================================

  Future<void>
      _finishCompletedTvShow(
    int showId,
  ) async {
    if (_finishingTvShows
        .contains(
      showId,
    )) {
      return;
    }

    _finishingTvShows.add(
      showId,
    );

    final int generation =
        _stateGeneration;

    try {
      if (!_isShowCompleted(
        showId,
      )) {
        return;
      }

      await _markAllShowEpisodesWatched(
        showId,
        generation,
      );

      // The user may have logged out,
      // switched account, removed the
      // show, or changed its status while
      // TMDB requests were running.
      if (generation !=
              _stateGeneration ||
          !_isShowCompleted(
            showId,
          )) {
        return;
      }

      await _saveEpisodes();
      await _saveEpisodeRuntimes();

      notifyListeners();

      _scheduleCloudSync();
    } catch (e) {
      debugPrint(
        'Could not finish completed TV show: $e',
      );
    } finally {
      _finishingTvShows.remove(
        showId,
      );
    }
  }

  bool _isShowCompleted(
    int showId,
  ) {
    final item =
        getItem(
      showId,
      'tv',
    );

    return item != null &&
        item.status ==
            'completed';
  }

  // =====================================================
  // BACKFILL OLD RUNTIMES / GENRES
  // =====================================================

  Future<void>
      backfillMissingRuntimes()
      async {
    final tmdb =
        TmdbService();

    bool changed = false;

    // -----------------------------------------
    // MOVIES + GENRES
    // -----------------------------------------

    for (int i = 0;
        i < _items.length;
        i++) {
      final item =
          _items[i];

      final needsGenres =
          item.genreIds.isEmpty;

      final needsMovieRuntime =
          item.mediaType ==
                  'movie' &&
              item.status ==
                  'completed' &&
              item.runtimeMinutes <=
                  0;

      if (!needsGenres &&
          !needsMovieRuntime) {
        continue;
      }

      try {
        final details =
            await tmdb
                .getDetails(
          item.id,
          item.mediaType,
        );

        int runtime =
            item.runtimeMinutes;

        if (needsMovieRuntime) {
          final rawRuntime =
              details['runtime'];

          if (rawRuntime
              is num) {
            runtime =
                rawRuntime.toInt();
          }
        }

        final rawGenres =
            details['genres'];

        List<int> genres =
            item.genreIds;

        if (rawGenres is List) {
          genres =
              rawGenres
                  .map<int?>(
            (genre) {
              if (genre is Map &&
                  genre['id']
                      is num) {
                return (genre[
                            'id']
                        as num)
                    .toInt();
              }

              return null;
            },
          ).whereType<int>().toList();
        }

        _items[i] =
            item.copyWith(
          runtimeMinutes:
              runtime,
          genreIds:
              genres,
        );

        changed = true;
      } catch (_) {
        // Skip items TMDB cannot load.
      }
    }

    // -----------------------------------------
    // OLD WATCHED EPISODES
    // -----------------------------------------

    final groups =
        <String, Set<int>>{};

    for (final key
        in _watchedEpisodes) {
      if ((_watchedEpisodeRuntimes[
                  key] ??
              0) >
          0) {
        continue;
      }

      final parts =
          key.split(':');

      if (parts.length !=
          3) {
        continue;
      }

      final showId =
          int.tryParse(
        parts[0],
      );

      final season =
          int.tryParse(
        parts[1],
      );

      final episode =
          int.tryParse(
        parts[2],
      );

      if (showId == null ||
          season == null ||
          episode == null) {
        continue;
      }

      final groupKey =
          '$showId:$season';

      groups
          .putIfAbsent(
            groupKey,
            () => <int>{},
          )
          .add(
            episode,
          );
    }

    for (final entry
        in groups.entries) {
      final parts =
          entry.key.split(':');

      final showId =
          int.parse(
        parts[0],
      );

      final season =
          int.parse(
        parts[1],
      );

      try {
        final episodes =
            await tmdb
                .getSeasonEpisodes(
          showId,
          season,
        );

        for (final episode
            in episodes) {
          final episodeNumber =
              episode[
                  'episode_number'];

          if (episodeNumber
              is! num) {
            continue;
          }

          final number =
              episodeNumber
                  .toInt();

          if (!entry.value
              .contains(
            number,
          )) {
            continue;
          }

          final runtime =
              episode[
                  'runtime'];

          if (runtime is num &&
              runtime.toInt() >
                  0) {
            final key =
                _episodeKey(
              showId,
              season,
              number,
            );

            _watchedEpisodeRuntimes[
                    key] =
                runtime.toInt();

            changed = true;
          }
        }
      } catch (_) {
        // Skip seasons TMDB cannot load.
      }
    }

    if (!changed) {
      return;
    }

    await _saveLibrary();
    await _saveEpisodeRuntimes();

    await syncToCloud();

    notifyListeners();
  }

  // =====================================================
  // LIBRARY LOOKUPS
  // =====================================================

  LibraryItem? getItem(
    int id,
    String mediaType,
  ) {
    final key =
        '$mediaType:$id';

    for (final item
        in _items) {
      if (item.uniqueKey ==
          key) {
        return item;
      }
    }

    return null;
  }

  bool contains(
    int id,
    String mediaType,
  ) {
    return getItem(
          id,
          mediaType,
        ) !=
        null;
  }

  // =====================================================
  // ADD / UPDATE ITEM
  // =====================================================

  Future<void> addOrUpdate(
    LibraryItem newItem,
  ) async {
    final index =
        _items.indexWhere(
      (item) =>
          item.uniqueKey ==
          newItem.uniqueKey,
    );

    final String? previousStatus =
    index == -1
        ? null
        : _items[index].status;

    if (index == -1) {
      _items.add(
        newItem,
      );
    } else {
      final oldItem =
          _items[index];

      _items[index] =
          LibraryItem(
        id:
            newItem.id,
        mediaType:
            newItem.mediaType,
        title:
            newItem.title,
        posterPath:
            newItem.posterPath,
        year:
            newItem.year,
        status:
            newItem.status,
        totalEpisodes:
            newItem
                .totalEpisodes,
        runtimeMinutes:
            newItem.runtimeMinutes >
                    0
                ? newItem
                    .runtimeMinutes
                : oldItem
                    .runtimeMinutes,
        genreIds:
            newItem.genreIds
                    .isNotEmpty
                ? newItem
                    .genreIds
                : oldItem
                    .genreIds,
        addedAt:
            oldItem.addedAt,
      );
    }

    final bool completeTvShow =
        newItem.mediaType ==
                'tv' &&
            newItem.status ==
                'completed';

    // UI changes immediately.
    notifyListeners();

    await _saveLibrary();

// =====================================
// COMMUNITY ACTIVITY
// =====================================

// =====================================
// COMMUNITY ACTIVITY
// =====================================

// STARTED WATCHING
if (newItem.mediaType == 'tv' &&
    newItem.status == 'watching' &&
    previousStatus != 'watching') {
  await CommunityService.instance
      .tryCreateActivity(
    activityType: 'started_watching',
    mediaType: 'tv',
    tmdbId: newItem.id,
    mediaTitle: newItem.title,
  );
}

// TV SHOW WATCHED
if (newItem.mediaType == 'tv' &&
    newItem.status == 'completed' &&
    previousStatus != 'completed') {
  await CommunityService.instance
      .tryCreateActivity(
    activityType: 'tv_watched',
    mediaType: 'tv',
    tmdbId: newItem.id,
    mediaTitle: newItem.title,
  );
}

// MOVIE WATCHED
if (newItem.mediaType == 'movie' &&
    newItem.status == 'completed' &&
    previousStatus != 'completed') {
  await CommunityService
      .instance
      .tryCreateActivity(
    activityType:
        'movie_watched',
    mediaType:
        'movie',
    tmdbId:
        newItem.id,
    mediaTitle:
        newItem.title,
  );
}

// PLAN TO WATCH
if (newItem.status == 'plan' &&
    previousStatus != 'plan') {
  await CommunityService
      .instance
      .tryCreateActivity(
    activityType:
        'plan_to_watch',
    mediaType:
        newItem.mediaType,
    tmdbId:
        newItem.id,
    mediaTitle:
        newItem.title,
  );
}

// DROPPED
if (newItem.status == 'dropped' &&
    previousStatus != 'dropped') {
  await CommunityService
      .instance
      .tryCreateActivity(
    activityType:
        'dropped',
    mediaType:
        newItem.mediaType,
    tmdbId:
        newItem.id,
    mediaTitle:
        newItem.title,
  );
}

// Debounced cloud sync.
_scheduleCloudSync();

    if (completeTvShow) {
      // Do not block the UI while
      // potentially fetching many
      // seasons from TMDB.
      unawaited(
        _finishCompletedTvShow(
          newItem.id,
        ),
      );
    }
  }

  // =====================================================
  // UPDATE STATUS
  // =====================================================

  Future<void> updateStatus(
    int id,
    String mediaType,
    String status,
  ) async {
    final index =
        _items.indexWhere(
      (item) =>
          item.id == id &&
          item.mediaType ==
              mediaType,
    );

    if (index == -1) {
      return;
    }

    final oldItem =
    _items[index];

final oldStatus =
    oldItem.status;

_items[index] =
    oldItem.copyWith(
  status:
      status,
);

    // Status changes visually
    // immediately.
    notifyListeners();

    await _saveLibrary();

    _scheduleCloudSync();

    // =====================================
// COMMUNITY ACTIVITY
// =====================================

if (mediaType == 'movie') {
  if (status == 'completed' &&
      oldStatus != 'completed') {
    await CommunityService
        .instance
        .tryCreateActivity(
      activityType:
          'movie_watched',
      mediaType:
          'movie',
      tmdbId:
          id,
      mediaTitle:
          _items[index]
              .title,
    );
  } else if (
      oldStatus == 'completed' &&
      status != 'completed') {
    try {
      await CommunityService
          .instance
          .deleteActivity(
        activityType:
            'movie_watched',
        mediaType:
            'movie',
        tmdbId:
            id,
      );
    } catch (e) {
      debugPrint(
        'Could not remove movie activity: $e',
      );
    }
  }
}

_scheduleCloudSync();

// =====================================
// STARTED WATCHING
// =====================================

if (mediaType == 'tv' &&
    status == 'watching' &&
    oldStatus != 'watching') {
  await CommunityService.instance
      .tryCreateActivity(
    activityType: 'started_watching',
    mediaType: 'tv',
    tmdbId: id,
    mediaTitle: _items[index].title,
  );
}

// =====================================
// TV SHOW WATCHED
// =====================================

if (mediaType == 'tv') {
  if (status == 'completed' &&
      oldStatus != 'completed') {
    await CommunityService.instance
        .tryCreateActivity(
      activityType:
          'tv_watched',
      mediaType:
          'tv',
      tmdbId:
          id,
      mediaTitle:
          _items[index].title,
    );
  } else if (
      oldStatus == 'completed' &&
      status != 'completed') {
    try {
      await CommunityService.instance
          .deleteActivity(
        activityType:
            'tv_watched',
        mediaType:
            'tv',
        tmdbId:
            id,
      );
    } catch (e) {
      debugPrint(
        'Could not remove TV watched activity: $e',
      );
    }
  }
}

// =====================================
// PLAN TO WATCH
// =====================================

if (status == 'plan' &&
    oldStatus != 'plan') {
  await CommunityService
      .instance
      .tryCreateActivity(
    activityType:
        'plan_to_watch',
    mediaType:
        mediaType,
    tmdbId:
        id,
    mediaTitle:
        _items[index].title,
  );
}

// =====================================
// DROPPED
// =====================================

if (status == 'dropped' &&
    oldStatus != 'dropped') {
  await CommunityService
      .instance
      .tryCreateActivity(
    activityType:
        'dropped',
    mediaType:
        mediaType,
    tmdbId:
        id,
    mediaTitle:
        _items[index].title,
  );
}

if (mediaType == 'tv' &&
    status ==
        'completed') {
      unawaited(
        _finishCompletedTvShow(
          id,
        ),
      );
    }
  }

  // =====================================================
  // REMOVE
  // =====================================================

  Future<void> remove(
    int id,
    String mediaType,
  ) async {
    _items.removeWhere(
      (item) =>
          item.id == id &&
          item.mediaType ==
              mediaType,
    );

    if (mediaType == 'tv') {
      final keysToRemove =
          _watchedEpisodes
              .where(
                (key) =>
                    key.startsWith(
                  '$id:',
                ),
              )
              .toList();

      for (final key
          in keysToRemove) {
        _watchedEpisodes
            .remove(
          key,
        );

        // Removing the whole show
        // intentionally deletes its
        // runtime history too.
        _watchedEpisodeRuntimes
            .remove(
          key,
        );
      }
    }

    if (mediaType == 'tv') {
  try {
    await CommunityService.instance
        .deleteActivity(
      activityType:
          'tv_watched',
      mediaType:
          'tv',
      tmdbId:
          id,
    );
  } catch (e) {
    debugPrint(
      'Could not remove TV watched activity: $e',
    );
  }
}

    // UI updates immediately.
    notifyListeners();

    if (mediaType == 'tv') {
      await _saveEpisodes();
      await _saveEpisodeRuntimes();
    }

    await _saveLibrary();

    _scheduleCloudSync();
  }

  

  // =====================================================
  // EPISODE HELPERS
  // =====================================================

  String _episodeKey(
    int showId,
    int seasonNumber,
    int episodeNumber,
  ) {
    return '$showId:'
        '$seasonNumber:'
        '$episodeNumber';
  }

  bool isEpisodeWatched(
    int showId,
    int seasonNumber,
    int episodeNumber,
  ) {
    return _watchedEpisodes
        .contains(
      _episodeKey(
        showId,
        seasonNumber,
        episodeNumber,
      ),
    );
  }

  // =====================================================
  // TOGGLE ONE EPISODE
  // =====================================================

Future<bool> _ensureTvShowIsWatching(
  int showId,
) async {
  final index =
      _items.indexWhere(
    (item) =>
        item.id == showId &&
        item.mediaType == 'tv',
  );

  // =========================================
  // SHOW ALREADY EXISTS
  // =========================================

  if (index != -1) {
    final item =
        _items[index];

    // Completed stays completed.
    if (item.status ==
        'completed') {
      return false;
    }

    // Already correct.
    if (item.status ==
        'watching') {
      return false;
    }

    // Plan / Dropped -> Watching
    _items[index] =
    item.copyWith(
  status: 'watching',
);

await CommunityService.instance
    .tryCreateActivity(
  activityType: 'started_watching',
  mediaType: 'tv',
  tmdbId: showId,
  mediaTitle: item.title,
);

return true;
  }

  // =========================================
  // SHOW DOES NOT EXIST IN LIBRARY
  // =========================================

  try {
    final details =
        await TmdbService()
            .getDetails(
      showId,
      'tv',
    );

    final String title =
        (details['name'] ??
                details['title'] ??
                'Unknown')
            .toString();

    final String? posterPath =
        details['poster_path']
            ?.toString();

    final String date =
        (details[
                    'first_air_date'] ??
                '')
            .toString();

    final String year =
        date.length >= 4
            ? date.substring(
                0,
                4,
              )
            : '';

    final int totalEpisodes =
        details[
                    'number_of_episodes']
                is num
            ? (details[
                        'number_of_episodes']
                    as num)
                .toInt()
            : 0;

    final List<int> genreIds =
        [];

    final rawGenres =
        details['genres'];

    if (rawGenres is List) {
      for (final genre
          in rawGenres) {
        if (genre is Map &&
            genre['id'] is num) {
          genreIds.add(
            (genre['id']
                    as num)
                .toInt(),
          );
        }
      }
    }

    _items.add(
  LibraryItem(
    id: showId,
    mediaType: 'tv',
    title: title,
    posterPath: posterPath,
    year: year,
    status: 'watching',
    totalEpisodes:
        totalEpisodes,
    runtimeMinutes: 0,
    genreIds: genreIds,
    addedAt:
        DateTime.now()
            .millisecondsSinceEpoch,
  ),
);

await CommunityService.instance
    .tryCreateActivity(
  activityType: 'started_watching',
  mediaType: 'tv',
  tmdbId: showId,
  mediaTitle: title,
);

return true;
  } catch (e) {
    debugPrint(
      'Could not auto-add TV show to Watching: $e',
    );

    return false;
  }
}

bool _removeTvShowIfNothingWatched(
  int showId,
) {
  // Still has at least one watched
  // episode -> keep it.
  if (watchedCountForShow(
        showId,
      ) >
      0) {
    return false;
  }

  final index =
      _items.indexWhere(
    (item) =>
        item.id == showId &&
        item.mediaType == 'tv',
  );

  if (index == -1) {
    return false;
  }

  final item =
      _items[index];

  // Only auto-remove something that
  // is currently in Watching.
  //
  // Completed / Plan / Dropped remain.
  if (item.status !=
      'watching') {
    return false;
  }

  _items.removeAt(
    index,
  );

  // Since there are zero watched
  // episodes, their cached runtime
  // is no longer needed.
  _watchedEpisodeRuntimes
      .removeWhere(
    (
      key,
      runtime,
    ) {
      return key.startsWith(
        '$showId:',
      );
    },
  );

  return true;
}

// =====================================================
// TOGGLE ONE EPISODE
// =====================================================

Future<void> toggleEpisode(
  int showId,
  int seasonNumber,
  int episodeNumber, {
  int runtimeMinutes = 0,
}) async {
  final key = _episodeKey(
    showId,
    seasonNumber,
    episodeNumber,
  );

  final bool wasWatched =
      _watchedEpisodes.contains(
    key,
  );

  bool libraryChanged =
      false;

  if (wasWatched) {
    // =====================================
    // UNWATCH EPISODE
    // =====================================

    _watchedEpisodes.remove(
      key,
    );

    // If this was the final watched
    // episode, remove the show from
    // Watch -> Watching.
    final removed =
        _removeTvShowIfNothingWatched(
      showId,
    );

    if (removed) {
      libraryChanged =
          true;
    }
  } else {
    // =====================================
    // WATCH EPISODE
    // =====================================

    _watchedEpisodes.add(
      key,
    );

    if (runtimeMinutes > 0) {
      _watchedEpisodeRuntimes[
              key] =
          runtimeMinutes;
    }
  }

  // Episode UI changes immediately.
  notifyListeners();

  await _saveEpisodes();
  await _saveEpisodeRuntimes();

  // Only after marking WATCHED do we
  // need to make sure the TV show exists
  // in Watching.
  if (!wasWatched) {
    final changed =
        await _ensureTvShowIsWatching(
      showId,
    );

    if (changed) {
      libraryChanged =
          true;

      // Watch page updates when the
      // show is added/moved.
      notifyListeners();
    }
  }

  if (libraryChanged) {
  await _saveLibrary();
}

// =====================================
// COMMUNITY ACTIVITY
// =====================================

final show =
    getItem(
  showId,
  'tv',
);

if (wasWatched) {
  // Episode was just UNWATCHED.
  // Remove its previous feed activity.
  try {
    await CommunityService
        .instance
        .deleteActivity(
      activityType:
          'episode_watched',
      mediaType:
          'tv',
      tmdbId:
          showId,
      seasonNumber:
          seasonNumber,
      episodeNumber:
          episodeNumber,
    );
  } catch (e) {
    debugPrint(
      'Could not remove episode activity: $e',
    );
  }
} else {
  // Episode was just WATCHED.
  await CommunityService
      .instance
      .tryCreateActivity(
    activityType:
        'episode_watched',
    mediaType:
        'tv',
    tmdbId:
        showId,
    mediaTitle:
        show?.title ??
            'Unknown TV Show',
    seasonNumber:
        seasonNumber,
    episodeNumber:
        episodeNumber,
  );
}

_scheduleCloudSync();
}

// =====================================================
// MARK WHOLE SEASON
// =====================================================

Future<void> markSeason(
  int showId,
  int seasonNumber,
  List<dynamic> episodes,
  bool watched,
) async {
  bool seasonChanged = false;

  for (final episode
      in episodes) {
    final rawEpisodeNumber =
        episode[
            'episode_number'];

    if (rawEpisodeNumber
        is! num) {
      continue;
    }

    final episodeNumber =
        rawEpisodeNumber
            .toInt();

    final key =
        _episodeKey(
      showId,
      seasonNumber,
      episodeNumber,
    );

    if (watched) {
  if (!_watchedEpisodes
      .contains(
    key,
  )) {
    seasonChanged = true;
  }

  _watchedEpisodes.add(
    key,
  );

      final runtime =
          episode[
              'runtime'];

      if (runtime is num &&
          runtime.toInt() >
              0) {
        _watchedEpisodeRuntimes[
                key] =
            runtime.toInt();
      }
    } else {
  if (_watchedEpisodes
      .contains(
    key,
  )) {
    seasonChanged = true;
  }

  _watchedEpisodes.remove(
    key,
  );

      // Keep runtime cached unless
      // the entire show reaches zero
      // watched episodes.
    }
  }

  bool libraryChanged =
      false;

  if (!watched) {
    // If clearing this season caused
    // the WHOLE SHOW to have zero
    // watched episodes, remove it
    // from Watching.
    final removed =
        _removeTvShowIfNothingWatched(
      showId,
    );

    if (removed) {
      libraryChanged =
          true;
    }
  }

  // Season UI updates immediately.
  notifyListeners();

  await _saveEpisodes();
  await _saveEpisodeRuntimes();

  if (watched) {
    // Marking any season watched means
    // the show belongs in Watching.
    final changed =
        await _ensureTvShowIsWatching(
      showId,
    );

    if (changed) {
      libraryChanged =
          true;

      notifyListeners();
    }
  }

  if (libraryChanged) {
  await _saveLibrary();
}

// =====================================
// COMMUNITY ACTIVITY
// =====================================

if (seasonChanged) {
  final show =
      getItem(
    showId,
    'tv',
  );

  if (watched) {
    await CommunityService
        .instance
        .tryCreateActivity(
      activityType:
          'season_watched',
      mediaType:
          'tv',
      tmdbId:
          showId,
      mediaTitle:
          show?.title ??
              'Unknown TV Show',
      seasonNumber:
          seasonNumber,
    );
  } else {
    try {
      await CommunityService
          .instance
          .deleteActivity(
        activityType:
            'season_watched',
        mediaType:
            'tv',
        tmdbId:
            showId,
        seasonNumber:
            seasonNumber,
      );
    } catch (e) {
      debugPrint(
        'Could not remove season activity: $e',
      );
    }
  }
}

_scheduleCloudSync();
}

  // =====================================================
  // COUNTS
  // =====================================================

  int watchedCountForShow(
    int showId,
  ) {
    return _watchedEpisodes
        .where(
          (key) =>
              key.startsWith(
            '$showId:',
          ),
        )
        .length;
  }

  int watchedCountForSeason(
    int showId,
    int seasonNumber,
  ) {
    return _watchedEpisodes
        .where(
          (key) =>
              key.startsWith(
            '$showId:'
            '$seasonNumber:',
          ),
        )
        .length;
  }

  int countByMediaType(
    String mediaType,
  ) {
    return _items
        .where(
          (item) =>
              item.mediaType ==
              mediaType,
        )
        .length;
  }

  int countByStatus(
    String status,
  ) {
    return _items
        .where(
          (item) =>
              item.status ==
              status,
        )
        .length;
  }

  // =====================================================
  // RECENT ITEMS
  // =====================================================

  List<LibraryItem>
      recentItems({
    int limit = 10,
  }) {
    final copy =
        List<LibraryItem>
            .from(
      _items,
    );

    copy.sort(
      (a, b) =>
          b.addedAt
              .compareTo(
        a.addedAt,
      ),
    );

    return copy
        .take(
          limit,
        )
        .toList();
  }

  // =====================================================
  // CONTINUE WATCHING
  // =====================================================

  List<LibraryItem>
      continueWatching({
    int limit = 10,
  }) {
    final list =
        _items.where(
      (item) {
        if (item.status !=
            'watching') {
          return false;
        }

        if (item.mediaType ==
            'movie') {
          return true;
        }

        final watched =
            watchedCountForShow(
          item.id,
        );

        return item.totalEpisodes ==
                0 ||
            watched <
                item.totalEpisodes;
      },
    ).toList();

    list.sort(
      (a, b) =>
          b.addedAt
              .compareTo(
        a.addedAt,
      ),
    );

    return list
        .take(
          limit,
        )
        .toList();
  }

  // =====================================================
  // SAFE SERIALIZED CLOUD UPLOAD
  // =====================================================

  Future<void> syncToCloud() {
    final cloud =
        CloudSyncService
            .instance;

    if (!cloud.isLoggedIn) {
      return Future.value();
    }

    // A sync should contain the newest
    // local state.
    _cloudSyncRequested =
        true;

    // Already syncing:
    // do not launch a second concurrent
    // upload. The running loop will
    // perform another pass afterwards.
    final active =
        _activeCloudSync;

    if (active != null) {
      return active;
    }

    final future =
        _runCloudSyncLoop();

    _activeCloudSync =
        future;

    return future;
  }

  Future<void>
      _runCloudSyncLoop()
      async {
    try {
      while (
          _cloudSyncRequested) {
        _cloudSyncRequested =
            false;

        await _syncToCloudOnce();
      }
    } finally {
      _activeCloudSync =
          null;
    }
  }

  Future<void>
      _syncToCloudOnce()
      async {
    final cloud =
        CloudSyncService
            .instance;

    if (!cloud.isLoggedIn) {
      return;
    }

    // Take complete snapshots before
    // beginning any network requests.
    final librarySnapshot =
        _items
            .map(
              (item) =>
                  item.toJson(),
            )
            .toList();

    final episodeSnapshot =
        <Map<String, int>>[];

    for (final key
        in _watchedEpisodes) {
      final parts =
          key.split(':');

      if (parts.length !=
          3) {
        continue;
      }

      final showId =
          int.tryParse(
        parts[0],
      );

      final seasonNumber =
          int.tryParse(
        parts[1],
      );

      final episodeNumber =
          int.tryParse(
        parts[2],
      );

      if (showId == null ||
          seasonNumber ==
              null ||
          episodeNumber ==
              null) {
        continue;
      }

      episodeSnapshot.add({
        'showId':
            showId,
        'seasonNumber':
            seasonNumber,
        'episodeNumber':
            episodeNumber,
        'runtimeMinutes':
            _watchedEpisodeRuntimes[
                    key] ??
                0,
      });
    }

    debugPrint(
  'CLOUD SYNC START',
);

await cloud.uploadLibrary(
  librarySnapshot,
);

debugPrint(
  'LIBRARY UPLOAD OK',
);

await cloud.uploadEpisodes(
  episodeSnapshot,
);

debugPrint(
  'EPISODE UPLOAD OK',
);
  }

  // =====================================================
  // WAIT / FLUSH CLOUD SYNC
  // =====================================================

  Future<void>
      waitForCloudSync()
      async {
    // A change may still be sitting in
    // the 500ms debounce timer.
    //
    // Flush it immediately before logout
    // or before replacing local state.
    if (_cloudSyncTimer
            ?.isActive ??
        false) {
      _cloudSyncTimer!
          .cancel();

      _cloudSyncTimer =
          null;

      await syncToCloud();
    }

    while (true) {
      final active =
          _activeCloudSync;

      if (active == null) {
        break;
      }

      await active;
    }
  }

  // =====================================================
  // SAFE CLOUD DOWNLOAD
  // =====================================================

  Future<void>
      syncFromCloud() async {
    final cloud =
        CloudSyncService
            .instance;

    if (!cloud.isLoggedIn) {
      return;
    }

    // Make sure pending local changes
    // are not racing with this download.
    await waitForCloudSync();

    // Download BOTH datasets completely
    // before touching current local data.
    final cloudLibrary =
        await cloud
            .downloadLibrary();

    final cloudEpisodes =
        await cloud
            .downloadEpisodes();

    // -----------------------------------------
    // BUILD TEMPORARY LIBRARY
    // -----------------------------------------

    final newItems =
        <LibraryItem>[];

    for (final item
        in cloudLibrary) {
      final rawId =
          item['tmdb_id'];

      final rawMediaType =
          item[
              'media_type'];

      if (rawId is! num ||
          rawMediaType ==
              null) {
        continue;
      }

      final rawTotalEpisodes =
          item[
              'total_episodes'];

      final rawRuntime =
          item[
              'runtime_minutes'];

      final rawAddedAt =
          item[
              'added_at'];

      final rawGenres =
          item[
              'genre_ids'];

      final genreIds =
          <int>[];

      if (rawGenres
          is List) {
        for (final value
            in rawGenres) {
          if (value is num) {
            genreIds.add(
              value.toInt(),
            );
          }
        }
      }

      newItems.add(
        LibraryItem(
          id:
              rawId.toInt(),
          mediaType:
              rawMediaType
                  .toString(),
          title:
              item['title']
                      ?.toString() ??
                  'Unknown',
          posterPath:
              item[
                      'poster_path']
                  ?.toString(),
          year:
              item['year']
                      ?.toString() ??
                  '',
          status:
              item['status']
                      ?.toString() ??
                  'plan',
          totalEpisodes:
              rawTotalEpisodes
                      is num
                  ? rawTotalEpisodes
                      .toInt()
                  : 0,
          runtimeMinutes:
              rawRuntime is num
                  ? rawRuntime
                      .toInt()
                  : 0,
          genreIds:
              genreIds,
          addedAt:
              rawAddedAt is num
                  ? rawAddedAt
                      .toInt()
                  : DateTime.now()
                      .millisecondsSinceEpoch,
        ),
      );
    }

    // -----------------------------------------
    // BUILD TEMPORARY EPISODE DATA
    // -----------------------------------------

    final newEpisodes =
        <String>{};

    final newEpisodeRuntimes =
        <String, int>{};

    for (final episode
        in cloudEpisodes) {
      final rawShowId =
          episode[
              'show_id'];

      final rawSeason =
          episode[
              'season_number'];

      final rawEpisode =
          episode[
              'episode_number'];

      if (rawShowId is! num ||
          rawSeason is! num ||
          rawEpisode is! num) {
        continue;
      }

      final key =
          _episodeKey(
        rawShowId.toInt(),
        rawSeason.toInt(),
        rawEpisode.toInt(),
      );

      newEpisodes.add(
        key,
      );

      final runtime =
          episode[
              'runtime_minutes'];

      if (runtime is num &&
          runtime.toInt() >
              0) {
        newEpisodeRuntimes[
                key] =
            runtime.toInt();
      }
    }

    // Anything still running from the
    // previous local/account state must
    // no longer be allowed to modify us.
    _stateGeneration++;

    // -----------------------------------------
    // ONLY NOW REPLACE CURRENT DATA
    // -----------------------------------------

    _items
      ..clear()
      ..addAll(
        newItems,
      );

    _watchedEpisodes
      ..clear()
      ..addAll(
        newEpisodes,
      );

    _watchedEpisodeRuntimes
      ..clear()
      ..addAll(
        newEpisodeRuntimes,
      );

    await _saveLibrary();
    await _saveEpisodes();
    await _saveEpisodeRuntimes();

    notifyListeners();
  }

  // =====================================================
  // CLEAR LOCAL DEVICE DATA
  //
  // Does NOT delete anything from Supabase.
  // =====================================================

  Future<void>
      clearLocalData()
      async {
    // Stop a pending debounced upload.
    _cloudSyncTimer?.cancel();

    _cloudSyncTimer =
        null;

    _cloudSyncRequested =
        false;

    // Cancel the logical ownership of
    // old background TMDB work.
    _stateGeneration++;

    _items.clear();

    _watchedEpisodes.clear();

    _watchedEpisodeRuntimes
        .clear();

    await _saveLibrary();
    await _saveEpisodes();
    await _saveEpisodeRuntimes();

    notifyListeners();
  }

  // =====================================================
  // VIEWER TITLE
  //
  // This preserves your ORIGINAL behavior:
  // all watched minutes count toward
  // every genre attached to that title.
  // =====================================================

  String get viewerTitle {
    final genreMinutes =
        <int, int>{};

    for (final item
        in _items) {
      final minutes =
          watchedMinutesForItem(
        item,
      );

      if (minutes <= 0 ||
          item.genreIds
              .isEmpty) {
        continue;
      }

      for (final genreId
          in item.genreIds
              .toSet()) {
        genreMinutes[
                genreId] =
            (genreMinutes[
                    genreId] ??
                0) +
            minutes;
      }
    }

    if (genreMinutes
        .isEmpty) {
      return 'VIEWER';
    }

    final dominant =
        genreMinutes.entries
            .reduce(
      (a, b) =>
          a.value >= b.value
              ? a
              : b,
    );

    return _titleForGenre(
      dominant.key,
    );
  }

  String _titleForGenre(
    int genreId,
  ) {
    switch (genreId) {
      // Movie / shared genres
      case 35:
        return 'COMEDIAN';

      case 28:
        return 'ACTION HERO';

      case 12:
        return 'EXPLORER';

      case 16:
        return 'TOONMASTER';

      case 80:
        return 'OUTLAW';

      case 99:
        return 'ARCHIVIST';

      case 18:
        return 'DRAMATIST';

      case 10751:
        return 'HEARTWARMER';

      case 14:
        return 'DREAMWEAVER';

      case 36:
        return 'HISTORIAN';

      case 27:
        return 'NIGHT DWELLER';

      case 10402:
        return 'MAESTRO';

      case 9648:
        return 'SLEUTH';

      case 10749:
        return 'ROMANTIC';

      case 878:
        return 'FUTURIST';

      case 53:
        return 'THRILL SEEKER';

      case 10752:
        return 'STRATEGIST';

      case 37:
        return 'GUNSLINGER';

      // TV-specific genres
      case 10759:
        return 'ADVENTURER';

      case 10762:
        return 'YOUNG AT HEART';

      case 10763:
        return 'NEWS HOUND';

      case 10764:
        return 'REALITY STAR';

      case 10765:
        return 'WORLDWALKER';

      case 10766:
        return 'SOAP DEVOTEE';

      case 10767:
        return 'CONVERSATIONALIST';

      case 10768:
        return 'STRATEGIST';

      default:
        return 'VIEWER';
    }
  }

  // =====================================================
  // MARK ALL EPISODES OF COMPLETED SHOW
  // =====================================================

  Future<void>
      _markAllShowEpisodesWatched(
    int showId,
    int generation,
  ) async {
    final tmdb =
        TmdbService();

    try {
      if (generation !=
              _stateGeneration ||
          !_isShowCompleted(
            showId,
          )) {
        return;
      }

      final details =
          await tmdb
              .getDetails(
        showId,
        'tv',
      );

      // Check again because the network
      // request above may have taken time.
      if (generation !=
              _stateGeneration ||
          !_isShowCompleted(
            showId,
          )) {
        return;
      }

      final List<dynamic>
          seasons =
          details['seasons'] ??
              [];

      for (final season
          in seasons) {
        if (generation !=
                _stateGeneration ||
            !_isShowCompleted(
              showId,
            )) {
          return;
        }

        final seasonNumber =
            season[
                'season_number'];

        if (seasonNumber
                is! num ||
            seasonNumber
                    .toInt() <=
                0) {
          continue;
        }

        final int seasonNumberInt =
            seasonNumber
                .toInt();

        final episodes =
            await tmdb
                .getSeasonEpisodes(
          showId,
          seasonNumberInt,
        );

        // User could have removed the
        // show or switched accounts while
        // this season was downloading.
        if (generation !=
                _stateGeneration ||
            !_isShowCompleted(
              showId,
            )) {
          return;
        }

        for (final episode
            in episodes) {
          final episodeNumber =
              episode[
                  'episode_number'];

          if (episodeNumber
              is! num) {
            continue;
          }

          final int
              episodeNumberInt =
              episodeNumber
                  .toInt();

          final key =
              _episodeKey(
            showId,
            seasonNumberInt,
            episodeNumberInt,
          );

          _watchedEpisodes
              .add(
            key,
          );

          final runtime =
              episode[
                  'runtime'];

          if (runtime is num &&
              runtime.toInt() >
                  0) {
            _watchedEpisodeRuntimes[
                    key] =
                runtime.toInt();
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Could not mark all episodes watched: $e',
      );
    }
  }
}