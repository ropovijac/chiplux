import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_service.dart';
import 'tmdb_service.dart';
import 'community_service.dart';
import 'startup_library_preview_service.dart';

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

  String get uniqueKey => '$mediaType:$id';

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
      status: status ?? this.status,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      genreIds: genreIds ?? this.genreIds,
      addedAt: addedAt ?? this.addedAt,
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
      'totalEpisodes': totalEpisodes,
      'runtimeMinutes': runtimeMinutes,
      'genreIds': genreIds,
      'addedAt': addedAt,
    };
  }

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: (json['id'] as num).toInt(),
      mediaType: json['mediaType'].toString(),
      title: json['title'] ?? 'Unknown',
      posterPath: json['posterPath'],
      year: json['year'] ?? '',
      status: json['status'] ?? 'plan',
      totalEpisodes: json['totalEpisodes'] is num
          ? (json['totalEpisodes'] as num).toInt()
          : 0,
      runtimeMinutes: json['runtimeMinutes'] is num
          ? (json['runtimeMinutes'] as num).toInt()
          : json['runtime_minutes'] is num
          ? (json['runtime_minutes'] as num).toInt()
          : 0,
      genreIds: List<int>.from(
        (json['genreIds'] ?? json['genre_ids'] ?? const <dynamic>[]).map(
          (value) => (value as num).toInt(),
        ),
      ),
      addedAt: json['addedAt'] is num
          ? (json['addedAt'] as num).toInt()
          : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class LibraryService extends ChangeNotifier {
  LibraryService._();

  static final LibraryService instance = LibraryService._();

  // Last server-confirmed state is stored separately for every Supabase UUID.
  // A failed write leaves it unchanged, so diffing the locally saved Library
  // against this checkpoint works after network failure and app restart.
  static const String _confirmedBaselinePrefix =
      'chiplux_library_server_baseline_v1_';
  static const String _pendingSignOutPrefix =
      'chiplux_library_pending_signout_v1_';
  static const String _verifiedLocalOwnerKey =
      'chiplux_startup_preview_verified_owner_v1';

  static const String _libraryKey = 'chiplux_library_v2';

  static const String _episodesKey = 'chiplux_watched_episodes_v2';

  static const String _episodeRuntimesKey =
      'chiplux_watched_episode_runtimes_v1';

  final List<LibraryItem> _items = [];

  final Set<String> _watchedEpisodes = {};

  final Map<String, int> _watchedEpisodeRuntimes = {};

  // Existing 500ms debounce.
  Timer? _cloudSyncTimer;

  // Prevent two actual cloud syncs
  // from running at the same time.
  Future<void>? _activeCloudSync;

  Timer? _cloudRetryTimer;
  int _consecutiveCloudFailures = 0;
  String? _adoptingGuestForNewAccount;

  bool _cloudSyncRequested = false;

  // Changes whenever the entire local
  // account state is replaced/cleared.
  //
  // This prevents an old async TMDB task
  // from modifying a newly signed-in
  // account's data.
  int _stateGeneration = 0;

  // Prevent a slow cloud download from overwriting a newer local edit.
  int _localRevision = 0;

  @override
  void notifyListeners() {
    _localRevision++;
    StartupLibraryPreviewService.instance.scheduleForLocalEdit(_startupPreviewRows);
    super.notifyListeners();
  }

  List<Map<String, dynamic>> _startupPreviewRows() => [
    for (final item in _items)
      {
        ...item.toJson(),
        if (item.mediaType == 'tv') 'episodesWatched': watchedCountForShow(item.id),
      },
  ];


  // Prevent duplicate background jobs
  // for the same completed TV show.
  final Set<int> _finishingTvShows = {};

  List<LibraryItem> get items => List.unmodifiable(_items);

  int get watchedEpisodeCount => _watchedEpisodes.length;

  int get moviesWatchedCount => _items
      .where((item) => item.mediaType == 'movie' && item.status == 'completed')
      .length;

  int get completedTvShowsCount => _items
      .where((item) => item.mediaType == 'tv' && item.status == 'completed')
      .length;

  int get completedCount =>
      _items.where((item) => item.status == 'completed').length;

  int get watchedEpisodeMinutes {
    int total = 0;

    for (final key in _watchedEpisodes) {
      total += _watchedEpisodeRuntimes[key] ?? 0;
    }

    return total;
  }

  int get watchedMovieMinutes {
    int total = 0;

    for (final item in _items) {
      if (item.mediaType == 'movie' && item.status == 'completed') {
        total += item.runtimeMinutes;
      }
    }

    return total;
  }

  int get totalWatchedMinutes {
    int total = 0;

    for (final key in _watchedEpisodes) {
      total += _watchedEpisodeRuntimes[key] ?? 0;
    }

    for (final item in _items) {
      if (item.mediaType == 'movie' && item.status == 'completed') {
        total += item.runtimeMinutes;
      }
    }

    return total;
  }

  int watchedMinutesForItem(LibraryItem item) {
    if (item.mediaType == 'movie') {
      if (item.status != 'completed') {
        return 0;
      }

      return item.runtimeMinutes;
    }

    if (item.mediaType == 'tv') {
      int total = 0;

      for (final key in _watchedEpisodes) {
        if (key.startsWith('${item.id}:')) {
          total += _watchedEpisodeRuntimes[key] ?? 0;
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
    final prefs = await SharedPreferences.getInstance();

    final libraryJson = prefs.getString(_libraryKey);

    if (libraryJson != null) {
      final List<dynamic> decoded = jsonDecode(libraryJson);

      _items
        ..clear()
        ..addAll(
          decoded.map(
            (item) => LibraryItem.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
    }

    final runtimesJson = prefs.getString(_episodeRuntimesKey);

    if (runtimesJson != null) {
      final decoded = Map<String, dynamic>.from(jsonDecode(runtimesJson));

      _watchedEpisodeRuntimes
        ..clear()
        ..addAll(
          decoded.map((key, value) => MapEntry(key, (value as num).toInt())),
        );
    }

    final watched = prefs.getStringList(_episodesKey);

    if (watched != null) {
      _watchedEpisodes
        ..clear()
        ..addAll(watched);
    }
  }

  // =====================================================
  // LOCAL SAVING
  // =====================================================

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _libraryKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveEpisodes() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_episodesKey, _watchedEpisodes.toList());
  }

  Future<void> _saveEpisodeRuntimes() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _episodeRuntimesKey,
      jsonEncode(_watchedEpisodeRuntimes),
    );
  }

  // =====================================================
  // DEBOUNCED CLOUD SYNC
  // =====================================================

  void _scheduleCloudSync() {
    _cloudSyncTimer?.cancel();

    _cloudSyncTimer = Timer(const Duration(milliseconds: 500), () async {
      _cloudSyncTimer = null;

      try {
        await syncToCloud();
      } catch (e) {
        debugPrint('Background cloud sync failed: $e');
      }
    });
  }

  // =====================================================
  // COMPLETED TV SHOW BACKGROUND PROCESS
  // =====================================================

  Future<void> _finishCompletedTvShow(int showId) async {
    if (_finishingTvShows.contains(showId)) {
      return;
    }

    _finishingTvShows.add(showId);

    final int generation = _stateGeneration;

    try {
      if (!_isShowCompleted(showId)) {
        return;
      }

      await _markAllShowEpisodesWatched(showId, generation);

      // The user may have logged out,
      // switched account, removed the
      // show, or changed its status while
      // TMDB requests were running.
      if (generation != _stateGeneration || !_isShowCompleted(showId)) {
        return;
      }

      await _saveEpisodes();
      await _saveEpisodeRuntimes();

      notifyListeners();

      _scheduleCloudSync();
    } catch (e) {
      debugPrint('Could not finish completed TV show: $e');
    } finally {
      _finishingTvShows.remove(showId);
    }
  }

  bool _isShowCompleted(int showId) {
    final item = getItem(showId, 'tv');

    return item != null && item.status == 'completed';
  }

  // =====================================================
  // BACKFILL OLD RUNTIMES / GENRES
  // =====================================================

  Future<void> backfillMissingRuntimes() async {
    final tmdb = TmdbService();

    bool changed = false;

    // -----------------------------------------
    // MOVIES + GENRES
    // -----------------------------------------

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      final needsGenres = item.genreIds.isEmpty;

      final needsMovieRuntime =
          item.mediaType == 'movie' &&
          item.status == 'completed' &&
          item.runtimeMinutes <= 0;

      if (!needsGenres && !needsMovieRuntime) {
        continue;
      }

      try {
        final details = await tmdb.getDetails(item.id, item.mediaType);

        int runtime = item.runtimeMinutes;

        if (needsMovieRuntime) {
          final rawRuntime = details['runtime'];

          if (rawRuntime is num) {
            runtime = rawRuntime.toInt();
          }
        }

        final rawGenres = details['genres'];

        List<int> genres = item.genreIds;

        if (rawGenres is List) {
          genres = rawGenres
              .map<int?>((genre) {
                if (genre is Map && genre['id'] is num) {
                  return (genre['id'] as num).toInt();
                }

                return null;
              })
              .whereType<int>()
              .toList();
        }

        _items[i] = item.copyWith(runtimeMinutes: runtime, genreIds: genres);

        changed = true;
      } catch (_) {
        // Skip items TMDB cannot load.
      }
    }

    // -----------------------------------------
    // OLD WATCHED EPISODES
    // -----------------------------------------

    final groups = <String, Set<int>>{};

    for (final key in _watchedEpisodes) {
      if ((_watchedEpisodeRuntimes[key] ?? 0) > 0) {
        continue;
      }

      final parts = key.split(':');

      if (parts.length != 3) {
        continue;
      }

      final showId = int.tryParse(parts[0]);

      final season = int.tryParse(parts[1]);

      final episode = int.tryParse(parts[2]);

      if (showId == null || season == null || episode == null) {
        continue;
      }

      final groupKey = '$showId:$season';

      groups.putIfAbsent(groupKey, () => <int>{}).add(episode);
    }

    for (final entry in groups.entries) {
      final parts = entry.key.split(':');

      final showId = int.parse(parts[0]);

      final season = int.parse(parts[1]);

      try {
        final episodes = await tmdb.getSeasonEpisodes(showId, season);

        for (final episode in episodes) {
          final episodeNumber = episode['episode_number'];

          if (episodeNumber is! num) {
            continue;
          }

          final number = episodeNumber.toInt();

          if (!entry.value.contains(number)) {
            continue;
          }

          final runtime = episode['runtime'];

          if (runtime is num && runtime.toInt() > 0) {
            final key = _episodeKey(showId, season, number);

            _watchedEpisodeRuntimes[key] = runtime.toInt();

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

  LibraryItem? getItem(int id, String mediaType) {
    final key = '$mediaType:$id';

    for (final item in _items) {
      if (item.uniqueKey == key) {
        return item;
      }
    }

    return null;
  }

  bool contains(int id, String mediaType) {
    return getItem(id, mediaType) != null;
  }

  // =====================================================
  // ADD / UPDATE ITEM
  // =====================================================

  Future<void> addOrUpdate(LibraryItem newItem) async {
    final index = _items.indexWhere(
      (item) => item.uniqueKey == newItem.uniqueKey,
    );

    final String? previousStatus = index == -1 ? null : _items[index].status;

    if (index == -1) {
      _items.add(newItem);
    } else {
      final oldItem = _items[index];

      _items[index] = LibraryItem(
        id: newItem.id,
        mediaType: newItem.mediaType,
        title: newItem.title,
        posterPath: newItem.posterPath,
        year: newItem.year,
        status: newItem.status,
        totalEpisodes: newItem.totalEpisodes,
        runtimeMinutes: newItem.runtimeMinutes > 0
            ? newItem.runtimeMinutes
            : oldItem.runtimeMinutes,
        genreIds: newItem.genreIds.isNotEmpty
            ? newItem.genreIds
            : oldItem.genreIds,
        addedAt: oldItem.addedAt,
      );
    }

    final bool completeTvShow =
        newItem.mediaType == 'tv' && newItem.status == 'completed';

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
      await CommunityService.instance.tryCreateActivity(
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
      await CommunityService.instance.tryCreateActivity(
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
      await CommunityService.instance.tryCreateActivity(
        activityType: 'movie_watched',
        mediaType: 'movie',
        tmdbId: newItem.id,
        mediaTitle: newItem.title,
      );
    }

    // PLAN TO WATCH
    if (newItem.status == 'plan' && previousStatus != 'plan') {
      await CommunityService.instance.tryCreateActivity(
        activityType: 'plan_to_watch',
        mediaType: newItem.mediaType,
        tmdbId: newItem.id,
        mediaTitle: newItem.title,
      );
    }

    // DROPPED
    if (newItem.status == 'dropped' && previousStatus != 'dropped') {
      await CommunityService.instance.tryCreateActivity(
        activityType: 'dropped',
        mediaType: newItem.mediaType,
        tmdbId: newItem.id,
        mediaTitle: newItem.title,
      );
    }

    // Debounced cloud sync.
    _scheduleCloudSync();

    if (completeTvShow) {
      // Do not block the UI while
      // potentially fetching many
      // seasons from TMDB.
      unawaited(_finishCompletedTvShow(newItem.id));
    }
  }

  // =====================================================
  // UPDATE STATUS
  // =====================================================

  Future<void> updateStatus(int id, String mediaType, String status) async {
    final index = _items.indexWhere(
      (item) => item.id == id && item.mediaType == mediaType,
    );

    if (index == -1) {
      return;
    }

    final oldItem = _items[index];

    final oldStatus = oldItem.status;

    _items[index] = oldItem.copyWith(status: status);

    // Status changes visually
    // immediately.
    notifyListeners();

    await _saveLibrary();

    _scheduleCloudSync();

    // =====================================
    // COMMUNITY ACTIVITY
    // =====================================

    if (mediaType == 'movie') {
      if (status == 'completed' && oldStatus != 'completed') {
        await CommunityService.instance.tryCreateActivity(
          activityType: 'movie_watched',
          mediaType: 'movie',
          tmdbId: id,
          mediaTitle: _items[index].title,
        );
      } else if (oldStatus == 'completed' && status != 'completed') {
        try {
          await CommunityService.instance.deleteActivity(
            activityType: 'movie_watched',
            mediaType: 'movie',
            tmdbId: id,
          );
        } catch (e) {
          debugPrint('Could not remove movie activity: $e');
        }
      }
    }

    _scheduleCloudSync();

    // =====================================
    // STARTED WATCHING
    // =====================================

    if (mediaType == 'tv' && status == 'watching' && oldStatus != 'watching') {
      await CommunityService.instance.tryCreateActivity(
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
      if (status == 'completed' && oldStatus != 'completed') {
        await CommunityService.instance.tryCreateActivity(
          activityType: 'tv_watched',
          mediaType: 'tv',
          tmdbId: id,
          mediaTitle: _items[index].title,
        );
      } else if (oldStatus == 'completed' && status != 'completed') {
        try {
          await CommunityService.instance.deleteActivity(
            activityType: 'tv_watched',
            mediaType: 'tv',
            tmdbId: id,
          );
        } catch (e) {
          debugPrint('Could not remove TV watched activity: $e');
        }
      }
    }

    // =====================================
    // PLAN TO WATCH
    // =====================================

    if (status == 'plan' && oldStatus != 'plan') {
      await CommunityService.instance.tryCreateActivity(
        activityType: 'plan_to_watch',
        mediaType: mediaType,
        tmdbId: id,
        mediaTitle: _items[index].title,
      );
    }

    // =====================================
    // DROPPED
    // =====================================

    if (status == 'dropped' && oldStatus != 'dropped') {
      await CommunityService.instance.tryCreateActivity(
        activityType: 'dropped',
        mediaType: mediaType,
        tmdbId: id,
        mediaTitle: _items[index].title,
      );
    }

    if (mediaType == 'tv' && status == 'completed') {
      unawaited(_finishCompletedTvShow(id));
    }
  }

  // =====================================================
  // REMOVE
  // =====================================================

  Future<void> remove(int id, String mediaType) async {
    _items.removeWhere((item) => item.id == id && item.mediaType == mediaType);

    if (mediaType == 'tv') {
      final keysToRemove = _watchedEpisodes
          .where((key) => key.startsWith('$id:'))
          .toList();

      for (final key in keysToRemove) {
        _watchedEpisodes.remove(key);

        // Removing the whole show
        // intentionally deletes its
        // runtime history too.
        _watchedEpisodeRuntimes.remove(key);
      }
    }

    if (mediaType == 'tv') {
      try {
        await CommunityService.instance.deleteActivity(
          activityType: 'tv_watched',
          mediaType: 'tv',
          tmdbId: id,
        );
      } catch (e) {
        debugPrint('Could not remove TV watched activity: $e');
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

  String _episodeKey(int showId, int seasonNumber, int episodeNumber) {
    return '$showId:'
        '$seasonNumber:'
        '$episodeNumber';
  }

  bool isEpisodeWatched(int showId, int seasonNumber, int episodeNumber) {
    return _watchedEpisodes.contains(
      _episodeKey(showId, seasonNumber, episodeNumber),
    );
  }

  /// The locally persisted runtime for this exact watched episode.
  int episodeRuntimeMinutes(int showId, int seasonNumber, int episodeNumber) =>
      _watchedEpisodeRuntimes[_episodeKey(showId, seasonNumber, episodeNumber)] ?? 0;

  /// Provides a single canonical watched row for an in-progress TV rating.
  /// Does not modify local state or mark unwatched episodes as watched.
  Map<String, int>? firstWatchedEpisodeForShow(int showId) {
    final prefix = '$showId:';
    for (final key in _watchedEpisodes) {
      if (!key.startsWith(prefix)) continue;
      final parts = key.split(':');
      if (parts.length != 3) continue;
      final season = int.tryParse(parts[1]);
      final episode = int.tryParse(parts[2]);
      if (season == null || episode == null) continue;
      return {
        'showId': showId,
        'seasonNumber': season,
        'episodeNumber': episode,
        'runtimeMinutes': _watchedEpisodeRuntimes[key] ?? 0,
      };
    }
    return null;
  }

  int _watchedRegularEpisodeCountForShow(int showId) {
    final prefix = '$showId:';

    return _watchedEpisodes.where((key) {
      if (!key.startsWith(prefix)) {
        return false;
      }

      // Season 0 is TMDB's specials season and should not
      // count toward normal-show completion.
      return !key.startsWith('$showId:0:');
    }).length;
  }

  Future<bool> _autoCompleteTvShowIfFullyWatched(int showId) async {
    final index = _items.indexWhere(
      (item) => item.id == showId && item.mediaType == 'tv',
    );

    if (index == -1) {
      return false;
    }

    final item = _items[index];

    // Auto-completion only applies to a show that is currently
    // being watched. Manually completed/plan/dropped states
    // are not touched here.
    if (item.status != 'watching' || item.totalEpisodes <= 0) {
      return false;
    }

    final watchedRegularEpisodes = _watchedRegularEpisodeCountForShow(showId);

    if (watchedRegularEpisodes < item.totalEpisodes) {
      return false;
    }

    _items[index] = item.copyWith(status: 'completed');

    notifyListeners();

    await _saveLibrary();

    try {
      await CommunityService.instance.tryCreateActivity(
        activityType: 'tv_watched',
        mediaType: 'tv',
        tmdbId: showId,
        mediaTitle: item.title,
      );
    } catch (e) {
      debugPrint('Could not create completed TV activity: $e');
    }

    _scheduleCloudSync();

    return true;
  }

  // =====================================================
  // TOGGLE ONE EPISODE
  // =====================================================

  Future<bool> _ensureTvShowIsWatching(int showId) async {
    final index = _items.indexWhere(
      (item) => item.id == showId && item.mediaType == 'tv',
    );

    // =========================================
    // SHOW ALREADY EXISTS
    // =========================================

    if (index != -1) {
      final item = _items[index];

      // Completed stays completed.
      if (item.status == 'completed') {
        return false;
      }

      // Already correct.
      if (item.status == 'watching') {
        return false;
      }

      // Plan / Dropped -> Watching
      _items[index] = item.copyWith(status: 'watching');

      await CommunityService.instance.tryCreateActivity(
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
      final details = await TmdbService().getDetails(showId, 'tv');

      final String title = (details['name'] ?? details['title'] ?? 'Unknown')
          .toString();

      final String? posterPath = details['poster_path']?.toString();

      final String date = (details['first_air_date'] ?? '').toString();

      final String year = date.length >= 4 ? date.substring(0, 4) : '';

      final int totalEpisodes = details['number_of_episodes'] is num
          ? (details['number_of_episodes'] as num).toInt()
          : 0;

      final List<int> genreIds = [];

      final rawGenres = details['genres'];

      if (rawGenres is List) {
        for (final genre in rawGenres) {
          if (genre is Map && genre['id'] is num) {
            genreIds.add((genre['id'] as num).toInt());
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
          totalEpisodes: totalEpisodes,
          runtimeMinutes: 0,
          genreIds: genreIds,
          addedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      await CommunityService.instance.tryCreateActivity(
        activityType: 'started_watching',
        mediaType: 'tv',
        tmdbId: showId,
        mediaTitle: title,
      );

      return true;
    } catch (e) {
      debugPrint('Could not auto-add TV show to Watching: $e');

      return false;
    }
  }

  bool _removeTvShowIfNothingWatched(int showId) {
    // Still has at least one watched
    // episode -> keep it.
    if (watchedCountForShow(showId) > 0) {
      return false;
    }

    final index = _items.indexWhere(
      (item) => item.id == showId && item.mediaType == 'tv',
    );

    if (index == -1) {
      return false;
    }

    final item = _items[index];

    // Only auto-remove something that
    // is currently in Watching.
    //
    // Completed / Plan / Dropped remain.
    if (item.status != 'watching') {
      return false;
    }

    _items.removeAt(index);

    // Since there are zero watched
    // episodes, their cached runtime
    // is no longer needed.
    _watchedEpisodeRuntimes.removeWhere((key, runtime) {
      return key.startsWith('$showId:');
    });

    return true;
  }

  // =====================================================
  // TOGGLE ONE EPISODE
  // =====================================================

  Future<bool> toggleEpisode(
    int showId,
    int seasonNumber,
    int episodeNumber, {
    int runtimeMinutes = 0,
  }) async {
    final key = _episodeKey(showId, seasonNumber, episodeNumber);

    final bool wasWatched = _watchedEpisodes.contains(key);

    bool libraryChanged = false;

    if (wasWatched) {
      // =====================================
      // UNWATCH EPISODE
      // =====================================

      _watchedEpisodes.remove(key);

      // If this was the final watched
      // episode, remove the show from
      // Watch -> Watching.
      final removed = _removeTvShowIfNothingWatched(showId);

      if (removed) {
        libraryChanged = true;
      }
    } else {
      // =====================================
      // WATCH EPISODE
      // =====================================

      _watchedEpisodes.add(key);

      if (runtimeMinutes > 0) {
        _watchedEpisodeRuntimes[key] = runtimeMinutes;
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
      final changed = await _ensureTvShowIsWatching(showId);

      if (changed) {
        libraryChanged = true;

        // Watch page updates when the
        // show is added/moved.
        notifyListeners();
      }
    }

    if (libraryChanged) {
      await _saveLibrary();
    }

    bool autoCompletedShow = false;

    if (!wasWatched) {
      autoCompletedShow = await _autoCompleteTvShowIfFullyWatched(showId);
    }

    // =====================================
    // COMMUNITY ACTIVITY
    // =====================================

    final show = getItem(showId, 'tv');

    if (wasWatched) {
      // Episode was just UNWATCHED.
      // Remove its previous feed activity.
      try {
        await CommunityService.instance.deleteActivity(
          activityType: 'episode_watched',
          mediaType: 'tv',
          tmdbId: showId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        );
      } catch (e) {
        debugPrint('Could not remove episode activity: $e');
      }
    } else {
      // Episode was just WATCHED.
      await CommunityService.instance.tryCreateActivity(
        activityType: 'episode_watched',
        mediaType: 'tv',
        tmdbId: showId,
        mediaTitle: show?.title ?? 'Unknown TV Show',
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    }

    _scheduleCloudSync();

    return autoCompletedShow;
  }

  // =====================================================
  // MARK WHOLE SEASON
  // =====================================================

  Future<bool> markSeason(
    int showId,
    int seasonNumber,
    List<dynamic> episodes,
    bool watched,
  ) async {
    bool seasonChanged = false;

    for (final episode in episodes) {
      final rawEpisodeNumber = episode['episode_number'];

      if (rawEpisodeNumber is! num) {
        continue;
      }

      final episodeNumber = rawEpisodeNumber.toInt();

      final key = _episodeKey(showId, seasonNumber, episodeNumber);

      if (watched) {
        if (!_watchedEpisodes.contains(key)) {
          seasonChanged = true;
        }

        _watchedEpisodes.add(key);

        final runtime = episode['runtime'];

        if (runtime is num && runtime.toInt() > 0) {
          _watchedEpisodeRuntimes[key] = runtime.toInt();
        }
      } else {
        if (_watchedEpisodes.contains(key)) {
          seasonChanged = true;
        }

        _watchedEpisodes.remove(key);

        // Keep runtime cached unless
        // the entire show reaches zero
        // watched episodes.
      }
    }

    bool libraryChanged = false;

    if (!watched) {
      // If clearing this season caused
      // the WHOLE SHOW to have zero
      // watched episodes, remove it
      // from Watching.
      final removed = _removeTvShowIfNothingWatched(showId);

      if (removed) {
        libraryChanged = true;
      }
    }

    // Season UI updates immediately.
    notifyListeners();

    await _saveEpisodes();
    await _saveEpisodeRuntimes();

    if (watched) {
      // Marking any season watched means
      // the show belongs in Watching.
      final changed = await _ensureTvShowIsWatching(showId);

      if (changed) {
        libraryChanged = true;

        notifyListeners();
      }
    }

    if (libraryChanged) {
      await _saveLibrary();
    }

    bool autoCompletedShow = false;

    if (watched) {
      autoCompletedShow = await _autoCompleteTvShowIfFullyWatched(showId);
    }

    // =====================================
    // COMMUNITY ACTIVITY
    // =====================================

    if (seasonChanged) {
      final show = getItem(showId, 'tv');

      if (watched) {
        await CommunityService.instance.tryCreateActivity(
          activityType: 'season_watched',
          mediaType: 'tv',
          tmdbId: showId,
          mediaTitle: show?.title ?? 'Unknown TV Show',
          seasonNumber: seasonNumber,
        );
      } else {
        try {
          await CommunityService.instance.deleteActivity(
            activityType: 'season_watched',
            mediaType: 'tv',
            tmdbId: showId,
            seasonNumber: seasonNumber,
          );
        } catch (e) {
          debugPrint('Could not remove season activity: $e');
        }
      }
    }

    _scheduleCloudSync();

    return autoCompletedShow;
  }

  // =====================================================
  // COUNTS
  // =====================================================

  int watchedCountForShow(int showId) {
    return _watchedEpisodes.where((key) => key.startsWith('$showId:')).length;
  }

  int watchedCountForSeason(int showId, int seasonNumber) {
    return _watchedEpisodes
        .where(
          (key) => key.startsWith(
            '$showId:'
            '$seasonNumber:',
          ),
        )
        .length;
  }

  int countByMediaType(String mediaType) {
    return _items.where((item) => item.mediaType == mediaType).length;
  }

  int countByStatus(String status) {
    return _items.where((item) => item.status == status).length;
  }

  // =====================================================
  // RECENT ITEMS
  // =====================================================

  List<LibraryItem> recentItems({int limit = 10}) {
    final copy = List<LibraryItem>.from(_items);

    copy.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return copy.take(limit).toList();
  }

  // =====================================================
  // CONTINUE WATCHING
  // =====================================================

  List<LibraryItem> continueWatching({int limit = 10}) {
    final list = _items.where((item) {
      if (item.status != 'watching') {
        return false;
      }

      if (item.mediaType == 'movie') {
        return true;
      }

      final watched = watchedCountForShow(item.id);

      return item.totalEpisodes == 0 || watched < item.totalEpisodes;
    }).toList();

    list.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return list.take(limit).toList();
  }

  // =====================================================
  // SAFE SERIALIZED CLOUD UPLOAD
  // =====================================================

  Future<void> syncToCloud({bool allowGuestAdoption = false}) {
    final cloud = CloudSyncService.instance;

    if (!cloud.isLoggedIn) {
      return Future.value();
    }

    // Guest Library adoption is permitted ONLY by the explicit verified
    // new-account path; a normal login must not upload leftover guest data.
    if (allowGuestAdoption) {
      _adoptingGuestForNewAccount = cloud.user?.id;
    }
    _cloudRetryTimer?.cancel();
    _cloudRetryTimer = null;
    // A sync should contain the newest
    // local state.
    _cloudSyncRequested = true;

    // Already syncing:
    // do not launch a second concurrent
    // upload. The running loop will
    // perform another pass afterwards.
    final active = _activeCloudSync;

    if (active != null) {
      return active;
    }

    final future = _runCloudSyncLoop();

    _activeCloudSync = future;

    return future;
  }

  Future<void> _runCloudSyncLoop() async {
    final userId = CloudSyncService.instance.user?.id;
    try {
      while (_cloudSyncRequested) {
        _cloudSyncRequested = false;
        await _syncToCloudOnce();
      }
      _consecutiveCloudFailures = 0;
    } catch (error) {
      // Only retry for the identical authenticated account. The baseline was
      // not advanced after failure; every delta operation is idempotent.
      if (userId != null && CloudSyncService.instance.user?.id == userId) {
        _scheduleCloudRetryForAccount(userId,
          allowGuestAdoption: _adoptingGuestForNewAccount == userId);
      }
      rethrow;
    } finally {
      _activeCloudSync = null;
      _adoptingGuestForNewAccount = null;
    }
  }

  void _scheduleCloudRetryForAccount(String userId,
      {bool allowGuestAdoption = false}) {
    _cloudRetryTimer?.cancel();
    if (CloudSyncService.instance.user?.id != userId) return;
    // Bounded backoff: 10, 20, 40, 80, 160, 300 seconds.
    final shift = _consecutiveCloudFailures > 5 ? 5 : _consecutiveCloudFailures;
    final proposedDelay = 10 << shift;
    final delay = proposedDelay > 300 ? 300 : proposedDelay;
    _consecutiveCloudFailures++;
    _cloudRetryTimer = Timer(Duration(seconds: delay), () async {
      _cloudRetryTimer = null;
      if (CloudSyncService.instance.user?.id != userId) return;
      try {
        await syncToCloud(allowGuestAdoption: allowGuestAdoption);
      } catch (error) {
        debugPrint('Library retry deferred again: $error');
      }
    });
  }

  // Durable diff helpers use stable, natural primary keys rather than list
  // order, so a single modified row doesn't rewrite an entire collection.
  Map<String, Map<String, dynamic>> _keyedLibrary(
      List<Map<String, dynamic>> items) => {
    for (final item in items) '${item['mediaType']}:${item['id']}': item,
  };

  Map<String, Map<String, int>> _keyedEpisodes(
      List<Map<String, int>> episodes) => {
    for (final ep in episodes)
      '${ep['showId']}:${ep['seasonNumber']}:${ep['episodeNumber']}': ep,
  };

  List<Map<String, int>> _episodeSnapshot({
    Set<String>? watched,
    Map<String, int>? runtimes,
  }) {
    final keys = watched ?? _watchedEpisodes;
    final lengths = runtimes ?? _watchedEpisodeRuntimes;
    final rows = <Map<String, int>>[];
    for (final key in keys) {
      final parts = key.split(':');
      if (parts.length != 3) continue;
      final show = int.tryParse(parts[0]);
      final season = int.tryParse(parts[1]);
      final episode = int.tryParse(parts[2]);
      if (show == null || season == null || episode == null) continue;
      rows.add({
        'showId': show,
        'seasonNumber': season,
        'episodeNumber': episode,
        'runtimeMinutes': lengths[key] ?? 0,
      });
    }
    return rows;
  }

  _LibraryCloudBaseline? _readCloudBaseline(String? json) {
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map ||
          decoded['items'] is! List ||
          decoded['episodes'] is! List) {
        return null;
      }
      return _LibraryCloudBaseline(
        items: [for (final raw in decoded['items'] as List)
          Map<String, dynamic>.from(raw as Map)],
        episodes: [for (final raw in decoded['episodes'] as List)
          Map<String, int>.from(raw as Map)],
      );
    } catch (e) {
      debugPrint('Invalid Library sync checkpoint: $e');
      return null;
    }
  }

  // Preserve account-scoped pending edits before a sign-out clears the global
  // local Library. The last confirmed checkpoint is saved alongside the
  // snapshot; only keys changed relative to it will be replayed on login.
  // Store it BEFORE Supabase signs out so even an offline sign-out is safe.
  Future<void> preservePendingChangesForSignOut() async {
    final userId = CloudSyncService.instance.user?.id;
    if (userId == null) return;
    // A running write may fail offline. Its checkpoint will remain unchanged.
    try {
      await waitForCloudSync();
    } catch (e) {
      debugPrint('Saving unsent Library edits for sign-out: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_verifiedLocalOwnerKey) != userId) return;
    final baseline = _readCloudBaseline(
      prefs.getString('$_confirmedBaselinePrefix$userId'),
    );
    if (baseline == null) return; // Never manufacture an unverified delta.
    final items = _items.map((item) => item.toJson()).toList();
    final episodes = _episodeSnapshot();
    final dirty = _hasCloudChanges(baseline, items, episodes);
    final pendingKey = '$_pendingSignOutPrefix$userId';
    if (dirty) {
      await prefs.setString(pendingKey, jsonEncode({
        'confirmedItems': baseline.items,
        'confirmedEpisodes': baseline.episodes,
        'items': items,
        'episodes': episodes,
      }));
    } else {
      // An earlier sign-out may have pending data; leave it intact until
      // successfully replayed for this account.
      if (!prefs.containsKey(pendingKey)) return;
    }
  }

  bool _hasCloudChanges(_LibraryCloudBaseline previous,
      List<Map<String, dynamic>> items, List<Map<String, int>> episodes) {
    final oldItems = _keyedLibrary(previous.items);
    final newItems = _keyedLibrary(items);
    final oldEpisodes = _keyedEpisodes(previous.episodes);
    final newEpisodes = _keyedEpisodes(episodes);
    if (oldItems.length != newItems.length ||
        oldEpisodes.length != newEpisodes.length) {
      return true;
    }
    for (final entry in newItems.entries) {
      if (!oldItems.containsKey(entry.key) ||
          jsonEncode(oldItems[entry.key]) != jsonEncode(entry.value)) {
        return true;
      }
    }
    for (final entry in newEpisodes.entries) {
      if (!oldEpisodes.containsKey(entry.key) ||
          jsonEncode(oldEpisodes[entry.key]) != jsonEncode(entry.value)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _replayPendingSignedOutChanges(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingKey = '$_pendingSignOutPrefix$userId';
    final raw = prefs.getString(pendingKey);
    if (raw == null) return;
    final data = jsonDecode(raw);
    if (data is! Map) throw StateError('Corrupt pending Library changes');
    final previous = _LibraryCloudBaseline(
      items: [for (final value in data['confirmedItems'] as List)
        Map<String, dynamic>.from(value as Map)],
      episodes: [for (final value in data['confirmedEpisodes'] as List)
        Map<String, int>.from(value as Map)],
    );
    final items = [for (final value in data['items'] as List)
      Map<String, dynamic>.from(value as Map)];
    final episodes = [for (final value in data['episodes'] as List)
      Map<String, int>.from(value as Map)];
    final oldItems = _keyedLibrary(previous.items);
    final newItems = _keyedLibrary(items);
    final oldEpisodes = _keyedEpisodes(previous.episodes);
    final newEpisodes = _keyedEpisodes(episodes);
    final cloud = CloudSyncService.instance;
    if (cloud.user?.id != userId) return;
    await cloud.uploadLibraryChanges(
      userId: userId,
      upserts: [for (final e in newItems.entries)
        if (!oldItems.containsKey(e.key) ||
            jsonEncode(oldItems[e.key]) != jsonEncode(e.value)) e.value],
      deletes: [for (final e in oldItems.entries)
        if (!newItems.containsKey(e.key)) e.value],
    );
    await cloud.uploadEpisodeChanges(
      userId: userId,
      upserts: [for (final e in newEpisodes.entries)
        if (!oldEpisodes.containsKey(e.key) ||
            jsonEncode(oldEpisodes[e.key]) != jsonEncode(e.value)) e.value],
      deletes: [for (final e in oldEpisodes.entries)
        if (!newEpisodes.containsKey(e.key)) e.value],
    );
    if (cloud.user?.id != userId) {
      throw StateError('Account changed during pending Library replay');
    }
    // On partial failure the durable pending queue is retained and replayed
    // idempotently next time. Clear only after both groups succeed.
    await prefs.remove(pendingKey);
  }

  Future<void> clearSyncMetadataForDeletedAccount(String? userId) async {
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_pendingSignOutPrefix$userId');
    await prefs.remove('$_confirmedBaselinePrefix$userId');
  }

  // Flush edits that were saved to local storage while this SAME account was
  // active on the previous run. Never upload unverified guest or other-account
  // data. This method is safe to call repeatedly and after connection returns.
  Future<void> resumePendingCloudSyncForCurrentAccount() async {
    final userId = CloudSyncService.instance.user?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_verifiedLocalOwnerKey) != userId ||
        _readCloudBaseline(
          prefs.getString('$_confirmedBaselinePrefix$userId')) == null) {
      return;
    }
    await syncToCloud();
  }

  Future<void> _syncToCloudOnce() async {
    final cloud = CloudSyncService.instance;
    final savingUserId = cloud.user?.id;
    if (savingUserId == null) return;
    final revisionAtStart = _localRevision;

    // Take immutable copies before awaiting the network. A later edit
    // triggers another pass; it cannot be silently acknowledged here.
    final librarySnapshot = _items.map((item) => item.toJson()).toList();
    final episodeSnapshot = _episodeSnapshot();
    final prefs = await SharedPreferences.getInstance();
    final knownOwner = prefs.getString(_verifiedLocalOwnerKey);
    if (knownOwner != null && knownOwner != savingUserId) {
      throw StateError('Local Library belongs to a different account.');
    }
    if (knownOwner == null && _adoptingGuestForNewAccount != savingUserId) {
      throw StateError('Unverified guest Library cannot be uploaded on sign-in.');
    }
    if (cloud.user?.id != savingUserId) {
      throw StateError('Account changed before Library synchronization.');
    }
    final baselineKey = '$_confirmedBaselinePrefix$savingUserId';
    final previous = _readCloudBaseline(prefs.getString(baselineKey));

    if (previous == null) {
      if (_adoptingGuestForNewAccount == savingUserId) {
        // A new account may adopt guest data ONLY if both server tables are
        // empty, never by deleting an existing user's cloud Library.
        final serverItems = await cloud.downloadLibrary();
        final serverEpisodes = await cloud.downloadEpisodes();
        if (serverItems.isNotEmpty || serverEpisodes.isNotEmpty) {
          throw StateError('Account already contains Library data; guest adoption stopped.');
        }
      }
      // First new-account guest upload, or migration from old full sync.
      // An existing account will acquire a baseline through syncFromCloud.
      debugPrint('CLOUD SYNC: first-time full reconciliation');
      await cloud.uploadLibrary(librarySnapshot);
      await cloud.uploadEpisodes(episodeSnapshot);
    } else {
      final oldItems = _keyedLibrary(previous.items);
      final newItems = _keyedLibrary(librarySnapshot);
      final oldEpisodes = _keyedEpisodes(previous.episodes);
      final newEpisodes = _keyedEpisodes(episodeSnapshot);

      final changedItems = <Map<String, dynamic>>[
        for (final entry in newItems.entries)
          if (!oldItems.containsKey(entry.key) ||
              jsonEncode(oldItems[entry.key]) != jsonEncode(entry.value))
            entry.value,
      ];
      final removedItems = <Map<String, dynamic>>[
        for (final entry in oldItems.entries)
          if (!newItems.containsKey(entry.key)) entry.value,
      ];
      final changedEpisodes = <Map<String, int>>[
        for (final entry in newEpisodes.entries)
          if (!oldEpisodes.containsKey(entry.key) ||
              jsonEncode(oldEpisodes[entry.key]) != jsonEncode(entry.value))
            entry.value,
      ];
      final removedEpisodes = <Map<String, int>>[
        for (final entry in oldEpisodes.entries)
          if (!newEpisodes.containsKey(entry.key)) entry.value,
      ];

      debugPrint('CLOUD SYNC DELTA: '
          '${changedItems.length} library upserts, '
          '${removedItems.length} library deletes, '
          '${changedEpisodes.length} episode upserts, '
          '${removedEpisodes.length} episode deletes');
      await cloud.uploadLibraryChanges(
        userId: savingUserId,
        upserts: changedItems,
        deletes: removedItems,
      );
      await cloud.uploadEpisodeChanges(
        userId: savingUserId,
        upserts: changedEpisodes,
        deletes: removedEpisodes,
      );
    }

    if (cloud.user?.id != savingUserId) {
      throw StateError('Account changed during Library synchronization.');
    }
    // Persist only CONFIRMED rows, and never snapshot newer unsent edits.
    await prefs.setString(
      baselineKey,
      jsonEncode({'items': librarySnapshot, 'episodes': episodeSnapshot}),
    );
    await prefs.setString(_verifiedLocalOwnerKey, savingUserId);
    if (_localRevision != revisionAtStart) {
      _cloudSyncRequested = true;
    }

    // Keep the existing Phase 2 account-scoped startup preview.
    if (cloud.user?.id == savingUserId) {
      await StartupLibraryPreviewService.instance.saveAfterVerifiedCloudSync(
        savingUserId, _startupPreviewRows(),
      );
    }
  }

  // =====================================================
  // WAIT / FLUSH CLOUD SYNC
  // =====================================================

  Future<void> waitForCloudSync() async {
    // A change may still be sitting in
    // the 500ms debounce timer.
    //
    // Flush it immediately before logout
    // or before replacing local state.
    if (_cloudSyncTimer?.isActive ?? false) {
      _cloudSyncTimer!.cancel();

      _cloudSyncTimer = null;

      await syncToCloud();
    }

    while (true) {
      final active = _activeCloudSync;

      if (active == null) {
        break;
      }

      await active;
    }
  }

  // =====================================================
  // SAFE CLOUD DOWNLOAD
  // =====================================================

  Future<void> syncFromCloud() async {
    final cloud = CloudSyncService.instance;

    if (!cloud.isLoggedIn) {
      return;
    }

    final userId = cloud.user?.id;
    if (userId == null) return;

    final prefsAtLogin = await SharedPreferences.getInstance();
    // A guest may have pending local saves; never send these into an existing
    // account on login. Explicit new-account adoption uses a separate path.
    if (prefsAtLogin.getString(_verifiedLocalOwnerKey) != userId) {
      _cloudSyncTimer?.cancel();
      _cloudSyncTimer = null;
      _cloudSyncRequested = false;
    }

    // Replay a sign-out's durable per-account pending changes before reading
    // the cloud snapshot. This never uploads the previous account's data.
    await _replayPendingSignedOutChanges(userId);

    // Restore any offline edits from this verified account before replacing
    // the local state with cloud data. Fail the refresh instead of dropping
    // unsent edits. Guest and other-account data is never uploaded here.
    await waitForCloudSync();
    await resumePendingCloudSyncForCurrentAccount();
    await waitForCloudSync();
    final generationBeforeDownload = _stateGeneration;
    final revisionBeforeDownload = _localRevision;

    // Download BOTH datasets completely
    // before touching current local data.
    final cloudLibrary = await cloud.downloadLibrary();
    if (cloud.user?.id != userId) return;

    final cloudEpisodes = await cloud.downloadEpisodes();

    // -----------------------------------------
    // BUILD TEMPORARY LIBRARY
    // -----------------------------------------

    final newItems = <LibraryItem>[];

    for (final item in cloudLibrary) {
      final rawId = item['tmdb_id'];

      final rawMediaType = item['media_type'];

      if (rawId is! num || rawMediaType == null) {
        continue;
      }

      final rawTotalEpisodes = item['total_episodes'];

      final rawRuntime = item['runtime_minutes'];

      final rawAddedAt = item['added_at'];

      final rawGenres = item['genre_ids'];

      final genreIds = <int>[];

      if (rawGenres is List) {
        for (final value in rawGenres) {
          if (value is num) {
            genreIds.add(value.toInt());
          }
        }
      }

      newItems.add(
        LibraryItem(
          id: rawId.toInt(),
          mediaType: rawMediaType.toString(),
          title: item['title']?.toString() ?? 'Unknown',
          posterPath: item['poster_path']?.toString(),
          year: item['year']?.toString() ?? '',
          status: item['status']?.toString() ?? 'plan',
          totalEpisodes: rawTotalEpisodes is num ? rawTotalEpisodes.toInt() : 0,
          runtimeMinutes: rawRuntime is num ? rawRuntime.toInt() : 0,
          genreIds: genreIds,
          addedAt: rawAddedAt is num
              ? rawAddedAt.toInt()
              : DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    // -----------------------------------------
    // BUILD TEMPORARY EPISODE DATA
    // -----------------------------------------

    final newEpisodes = <String>{};

    final newEpisodeRuntimes = <String, int>{};

    for (final episode in cloudEpisodes) {
      final rawShowId = episode['show_id'];

      final rawSeason = episode['season_number'];

      final rawEpisode = episode['episode_number'];

      if (rawShowId is! num || rawSeason is! num || rawEpisode is! num) {
        continue;
      }

      final key = _episodeKey(
        rawShowId.toInt(),
        rawSeason.toInt(),
        rawEpisode.toInt(),
      );

      newEpisodes.add(key);

      final runtime = episode['runtime_minutes'];

      if (runtime is num && runtime.toInt() > 0) {
        newEpisodeRuntimes[key] = runtime.toInt();
      }
    }

    // Do not overwrite edits made while the network was loading, or data
    // belonging to an account that signed out or changed in the meantime.
    if (cloud.user?.id != userId ||
        generationBeforeDownload != _stateGeneration ||
        revisionBeforeDownload != _localRevision) {
      debugPrint('Discarding stale startup Library refresh.');
      return;
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
      ..addAll(newItems);

    _watchedEpisodes
      ..clear()
      ..addAll(newEpisodes);

    _watchedEpisodeRuntimes
      ..clear()
      ..addAll(newEpisodeRuntimes);

    await _saveLibrary();
    await _saveEpisodes();
    await _saveEpisodeRuntimes();

    // A complete, verified download also establishes an exact diff baseline.
    // No writes to Supabase happen here.
    if (cloud.user?.id != userId) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_confirmedBaselinePrefix$userId',
      jsonEncode({
        'items': newItems.map((item) => item.toJson()).toList(),
        'episodes': _episodeSnapshot(
          watched: newEpisodes, runtimes: newEpisodeRuntimes,
        ),
      }),
    );
    await prefs.setString(_verifiedLocalOwnerKey, userId);

    // Verified cloud download establishes ownership of the new local state.
    await StartupLibraryPreviewService.instance.saveAfterVerifiedCloudSync(
      userId, _startupPreviewRows(),
    );
    notifyListeners();
  }

  // =====================================================
  // CLEAR LOCAL DEVICE DATA
  //
  // Does NOT delete anything from Supabase.
  // =====================================================

  Future<void> clearLocalData() async {
    // Stop a pending debounced upload.
    _cloudSyncTimer?.cancel();

    _cloudSyncTimer = null;

    _cloudSyncRequested = false;
    _cloudRetryTimer?.cancel();
    _cloudRetryTimer = null;
    _consecutiveCloudFailures = 0;

    // Cancel the logical ownership of
    // old background TMDB work.
    _stateGeneration++;

    _items.clear();

    _watchedEpisodes.clear();

    _watchedEpisodeRuntimes.clear();

    await _saveLibrary();
    await _saveEpisodes();
    await _saveEpisodeRuntimes();

    // Local data is no longer owned by the old signed-in user after logout.
    // Keep per-user confirmed checkpoints: they are inert without ownership.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_verifiedLocalOwnerKey);
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
    final genreMinutes = <int, int>{};

    for (final item in _items) {
      final minutes = watchedMinutesForItem(item);

      if (minutes <= 0 || item.genreIds.isEmpty) {
        continue;
      }

      for (final genreId in item.genreIds.toSet()) {
        genreMinutes[genreId] = (genreMinutes[genreId] ?? 0) + minutes;
      }
    }

    if (genreMinutes.isEmpty) {
      return 'VIEWER';
    }

    final dominant = genreMinutes.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return _titleForGenre(dominant.key);
  }

  String _titleForGenre(int genreId) {
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

  Future<void> _markAllShowEpisodesWatched(int showId, int generation) async {
    final tmdb = TmdbService();

    try {
      if (generation != _stateGeneration || !_isShowCompleted(showId)) {
        return;
      }

      final details = await tmdb.getDetails(showId, 'tv');

      // Check again because the network
      // request above may have taken time.
      if (generation != _stateGeneration || !_isShowCompleted(showId)) {
        return;
      }

      final List<dynamic> seasons = details['seasons'] ?? [];

      for (final season in seasons) {
        if (generation != _stateGeneration || !_isShowCompleted(showId)) {
          return;
        }

        final seasonNumber = season['season_number'];

        if (seasonNumber is! num || seasonNumber.toInt() <= 0) {
          continue;
        }

        final int seasonNumberInt = seasonNumber.toInt();

        final episodes = await tmdb.getSeasonEpisodes(showId, seasonNumberInt);

        // User could have removed the
        // show or switched accounts while
        // this season was downloading.
        if (generation != _stateGeneration || !_isShowCompleted(showId)) {
          return;
        }

        for (final episode in episodes) {
          final episodeNumber = episode['episode_number'];

          if (episodeNumber is! num) {
            continue;
          }

          final int episodeNumberInt = episodeNumber.toInt();

          final key = _episodeKey(showId, seasonNumberInt, episodeNumberInt);

          _watchedEpisodes.add(key);

          final runtime = episode['runtime'];

          if (runtime is num && runtime.toInt() > 0) {
            _watchedEpisodeRuntimes[key] = runtime.toInt();
          }
        }
      }
    } catch (e) {
      debugPrint('Could not mark all episodes watched: $e');
    }
  }
}

class _LibraryCloudBaseline {
  const _LibraryCloudBaseline({required this.items, required this.episodes});
  final List<Map<String, dynamic>> items;
  final List<Map<String, int>> episodes;
}
