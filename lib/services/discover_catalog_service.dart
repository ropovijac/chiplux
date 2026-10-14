import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import 'tmdb_service.dart';
import 'locale_service.dart';

enum DiscoverCategory { movies, tvShows, albums, songs }

enum DiscoverMode { trending, top100, forYou }

class DiscoverGenre {
  final int id;
  final String name;
  const DiscoverGenre(this.id, this.name);
}

class DiscoverCatalogService {
  DiscoverCatalogService._();
  static final instance = DiscoverCatalogService._();
  final _cache = <String, ({DateTime time, List<Map<String, dynamic>> rows})>{};
  final _pending = <String, Future<List<Map<String, dynamic>>>>{};
  final _networkWaiters = <Completer<void>>[];
  int _activeRequests = 0;
  final _genreRequests = <String, Future<List<DiscoverGenre>>>{};
  SharedPreferences? _preferences;
  Future<void>? _initialization;
  Future<void>? _preload;
  static const _diskPrefix = 'chiplux_discover_v4:';

  Future<void> _initialize() => _initialization ??= _restore();
  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _preferences = preferences;
      for (final key in preferences.getKeys().where(
        (key) => key.startsWith(_diskPrefix),
      )) {
        try {
          final data = jsonDecode(preferences.getString(key)!) as Map;
          final time = DateTime.parse(data['time'] as String);
          if (!key.contains('albums:studio:') &&
              DateTime.now().difference(time) > const Duration(days: 7)) {
            await preferences.remove(key);
            continue;
          }
          _cache.putIfAbsent(
            key.substring(_diskPrefix.length),
            () => (
              time: time,
              rows: (data['rows'] as List)
                  .map((row) => Map<String, dynamic>.from(row as Map))
                  .toList(),
            ),
          );
        } catch (_) {
          /* Ignore an incomplete or obsolete local cache. */
        }
      }
    } catch (_) {
      /* Loading from the network remains available. */
    }
  }

  Future<void> _persist(String key, List<Map<String, dynamic>> rows) async {
    try {
      await _preferences?.setString(
        '$_diskPrefix$key',
        jsonEncode({
          'time': (_cache[key]?.time ?? DateTime.now()).toIso8601String(),
          'rows': rows,
        }),
      );
    } catch (_) {
      /* A cache write must not fail a catalog request. */
    }
  }

  // Start overall lists for every media tab before loading background genres.
  Future<void> preload() => _preload ??= _preloadAll();
  Future<void> _preloadAll() async {
    await _initialize();
    await Future.wait(
      [
        DiscoverCategory.movies,
        DiscoverCategory.tvShows,
        DiscoverCategory.albums,
      ].map((category) async {
        try {
          await _sharedCategory(category);
        } catch (_) {
          /* Saved results remain usable. */
        }
        try {
          await genres(category);
        } catch (_) {
          /* Retry when opened. */
        }
        for (final mode in [DiscoverMode.trending, DiscoverMode.top100]) {
          try {
            await load(category, mode);
          } catch (_) {
            /* Keep navigation available. */
          }
        }
      }),
    );
  }

  Future<void> preloadCategory(
    DiscoverCategory category,
    DiscoverMode mode,
  ) async {
    try {
      await _sharedCategory(category);
    } catch (_) {
      /* The section shows Retry. */
    }
  }

  final _sharedRequests =
      <String, Future<Map<String, List<Map<String, dynamic>>>>>{};
  final _sharedData =
      <
        String,
        ({DateTime time, Map<String, List<Map<String, dynamic>>> data})
      >{};
  Future<Map<String, List<Map<String, dynamic>>>> _sharedCategory(
    DiscoverCategory category, {
    bool force = false,
  }) async {
    await _initialize();
    final language = isMusic(category)
        ? '*'
        : (LocaleService.instance.effectiveLanguageCode == 'hr'
              ? 'hr-HR'
              : 'en-US');
    final key = '${category.name}:$language';
    final cached = _sharedData[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.time) < const Duration(minutes: 30)) {
      return cached.data;
    }
    return _sharedRequests.putIfAbsent(key, () async {
      try {
        final result =
            await (category == DiscoverCategory.albums
                    ? Supabase.instance.client.rpc('chiplux_get_album_catalog')
                    : Supabase.instance.client.rpc(
                        'chiplux_get_discover_cache',
                        params: {
                          'p_category': category.name,
                          'p_language': language,
                        },
                      ))
                .timeout(const Duration(seconds: 8));
        final data = <String, List<Map<String, dynamic>>>{};
        if (result is List) {
          for (final record in result.whereType<Map>()) {
            final rows = (record['items'] as List? ?? [])
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
            if (category == DiscoverCategory.albums &&
                (rows.isEmpty || rows.any((row) => !_readyAlbum(row)))) {
              continue;
            }
            final mode = record['mode']?.toString();
            final genre = (record['genre_id'] as num?)?.toInt() ?? 0;
            data['$mode:$genre'] = rows;
            final stamp =
                DateTime.tryParse(record['updated_at']?.toString() ?? '') ??
                DateTime.now();
            final localLanguage =
                LocaleService.instance.effectiveLanguageCode == 'hr'
                ? 'hr-HR'
                : 'en-US';
            final modes = mode == 'trending' ? ['trending', 'forYou'] : [mode];
            for (final cachedMode in modes) {
              final cacheKey = cachedMode == 'genres'
                  ? 'genres:${category.name}:$localLanguage'
                  : '${category.name}:$cachedMode:${genre == 0 ? 'null' : genre}:$localLanguage';
              _cache[cacheKey] = (time: stamp, rows: rows);
              unawaited(_persist(cacheKey, rows));
            }
          }
        }
        if (category == DiscoverCategory.albums && data.isEmpty) {
          throw StateError('The studio album cache has not been filled yet.');
        }
        _sharedData[key] = (time: DateTime.now(), data: data);
        return data;
      } catch (_) {
        if (category == DiscoverCategory.albums) {
          rethrow;
        }
        return <String, List<Map<String, dynamic>>>{};
      } finally {
        _sharedRequests.remove(key);
      }
    });
  }

  Future<List<Map<String, dynamic>>?> specialList(
    DiscoverCategory category,
    int genreId,
  ) async {
    final data = await _sharedCategory(category);
    final language = LocaleService.instance.effectiveLanguageCode == 'hr'
        ? 'hr-HR'
        : 'en-US';
    return data['top100:$genreId'] ??
        _cache['${category.name}:top100:${genreId == 0 ? 'null' : genreId}:$language']
            ?.rows;
  }

  static const musicCountry = 'us';
  static const musicGenres = <DiscoverGenre>[
    DiscoverGenre(20, 'Alternative'),
    DiscoverGenre(2, 'Blues'),
    DiscoverGenre(1122, 'Brazilian'),
    DiscoverGenre(4, 'Children’s Music'),
    DiscoverGenre(22, 'Christian & Gospel'),
    DiscoverGenre(5, 'Classical'),
    DiscoverGenre(3, 'Comedy'),
    DiscoverGenre(6, 'Country'),
    DiscoverGenre(17, 'Dance'),
    DiscoverGenre(7, 'Electronic'),
    DiscoverGenre(1153, 'Metal'),
    DiscoverGenre(10, 'Singer/Songwriter'),
    DiscoverGenre(18, 'Hip-Hop/Rap'),
    DiscoverGenre(8, 'Holiday'),
    DiscoverGenre(52, 'Indian'),
    DiscoverGenre(53, 'Instrumental'),
    DiscoverGenre(11, 'Jazz'),
    DiscoverGenre(27, 'J-Pop'),
    DiscoverGenre(51, 'K-Pop'),
    DiscoverGenre(12, 'Latin'),
    DiscoverGenre(13, 'New Age'),
    DiscoverGenre(14, 'Pop'),
    DiscoverGenre(15, 'R&B/Soul'),
    DiscoverGenre(24, 'Reggae'),
    DiscoverGenre(21, 'Rock'),
    DiscoverGenre(16, 'Soundtrack'),
    DiscoverGenre(23, 'Vocal'),
    DiscoverGenre(19, 'World'),
  ];
  static bool isMusic(DiscoverCategory category) =>
      category == DiscoverCategory.albums || category == DiscoverCategory.songs;
  static String mediaType(DiscoverCategory category) =>
      category == DiscoverCategory.movies ? 'movie' : 'tv';

  // Curated discovery uses existing cached all-time/genre results for albums,
  // and TMDB's discover endpoint for year and niche media filters.
  Future<List<Map<String, dynamic>>> curatedList(
    DiscoverCategory category, {
    int? genreId,
    int? startYear,
    String? misc,
    bool force = false,
  }) async {
    if (category == DiscoverCategory.albums) {
      final effectiveGenre = switch (misc) {
        'Instrumental' => 53,
        'Soundtracks' => 16,
        _ => genreId,
      };
      var rows = await load(category, DiscoverMode.top100,
        genreId: effectiveGenre, force: force);
      // Pool additional genres for albums so the decade selection has
      // more than a single chart's candidates.
      if (startYear != null || misc == 'Hidden Gems' || misc == 'Modern Classics' || misc == '90s Albums') {
        final shared = await _sharedCategory(category, force: force);
        final uniques = <String, Map<String, dynamic>>{};
        for (final batch in shared.entries.where((entry) => entry.key.startsWith('studio:'))) {
          for (final album in batch.value) {
            final id = album['id']?.toString() ?? '';
            if (id.isNotEmpty) uniques.putIfAbsent(id, () => album);
          }
        }
        if (uniques.isNotEmpty) rows = uniques.values.toList();
      }
      int? yearOf(Map<String, dynamic> album) {
        final date = album['first_release_date']?.toString() ?? '';
        return date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;
      }
      if (startYear != null) {
        rows = rows.where((album) =>
          (yearOf(album) ?? 0) >= startYear && (yearOf(album) ?? 9999) < startYear + 10).toList();
      }
      if (misc == '90s Albums') {
        rows = rows.where((a) => (yearOf(a) ?? 0) >= 1990 && (yearOf(a) ?? 9999) < 2000).toList();
      } else if (misc == 'Modern Classics') {
        rows = rows.where((a) => (yearOf(a) ?? 0) >= 2000 && (yearOf(a) ?? 9999) < 2020).toList();
      } else if (misc == 'Hidden Gems') {
        // Lower-charted catalog albums; an obscurity proxy, not a critic score.
        rows = rows.where((a) => ((a['chart_rank'] as num?)?.toInt() ?? 0) >= 30).toList();
      }
      return rows.take(100).toList();
    }
    if (startYear == null && misc == null) {
      return load(category, DiscoverMode.top100, genreId: genreId, force: force);
    }
    final type = mediaType(category);
    final isMovie = type == 'movie';
    int? effectiveGenre = genreId;
    if (misc != null) {
      effectiveGenre = switch (misc) {
        'Animated Movies' => 16,
        'Sitcoms & Comedy' => 35,
        'Anime & Animation' => 16,
        'Documentaries' => 99,
        'Crime Series' => 80,
        _ => null,
      };
    }
    if (misc == 'Under 90 Minutes' || misc == 'Superhero Movies' || misc == 'Hidden Gems') {
      final id = switch (misc) {
        'Under 90 Minutes' => -1,
        'Superhero Movies' => -2,
        _ => -3,
      };
      final saved = await specialList(category, id);
      if (saved != null && saved.isNotEmpty) return saved.take(100).toList();
      // Runtime-specified lists use the existing TMDB service fallback.
      final tmdb = TmdbService();
      final List<dynamic> result = switch (id) {
        -1 => await tmdb.getTop100ShortMovies(),
        -2 => await tmdb.getTop100SuperheroMovies(),
        _ => await tmdb.getTop100HiddenGems(),
      };
      return result.whereType<Map>().map((a) => Map<String, dynamic>.from(a)).take(100).toList();
    }
    final language = LocaleService.instance.effectiveLanguageCode == 'hr' ? 'hr-HR' : 'en-US';
    final key = 'curated:${category.name}:$startYear:$misc:$effectiveGenre:$language';
    if (!force && _cache.containsKey(key)) return _cache[key]!.rows;
    final minVotes = isMovie ? '250' : '100';
    final query = <String, String>{
      'api_key': TmdbService.apiKey,
      'language': language,
      'include_adult': 'false',
      'sort_by': 'vote_average.desc',
      'vote_count.gte': minVotes,
      if (effectiveGenre != null) 'with_genres': '$effectiveGenre',
      if (startYear != null) '${isMovie ? 'primary_release_date' : 'first_air_date'}.gte': '$startYear-01-01',
      if (startYear != null) '${isMovie ? 'primary_release_date' : 'first_air_date'}.lte': '${startYear + 9}-12-31',
    };
    final first = await _get(Uri.parse('${TmdbService.baseUrl}/discover/$type')
      .replace(queryParameters: {...query, 'page': '1'}));
    final totalPages = (first['total_pages'] as num?)?.toInt() ?? 1;
    final pages = <Map<String, dynamic>>[first];
    pages.addAll(await Future.wait([
      for (var page = 2; page <= 5 && page <= totalPages; page++)
        _get(Uri.parse('${TmdbService.baseUrl}/discover/$type')
          .replace(queryParameters: {...query, 'page': '$page'})),
    ]));
    final seen = <int>{};
    final rows = <Map<String, dynamic>>[];
    for (final page in pages) {
      for (final element in (page['results'] as List? ?? []).whereType<Map>()) {
        final item = Map<String, dynamic>.from(element);
        final id = (item['id'] as num?)?.toInt();
        if (id != null && seen.add(id)) rows.add(item);
      }
    }
    final result = rows.take(100).toList();
    _cache[key] = (time: DateTime.now(), rows: result);
    unawaited(_persist(key, result));
    return result;
  }

  Future<List<Map<String, dynamic>>> searchCachedAlbums(String query) async {
    final clean = query.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9\u00c0-\u024f]+'),
      ' ',
    );
    if (clean.length < 2) return const [];
    final words = clean.split(' ').where((word) => word.isNotEmpty).toList();
    final data = await _sharedCategory(DiscoverCategory.albums);
    final matches = <String, Map<String, dynamic>>{};
    for (final entry in data.entries.where(
      (entry) => entry.key.startsWith('studio:'),
    )) {
      for (final row in entry.value) {
        final title = row['name']?.toString().toLowerCase() ?? '';
        final artist = row['artist_name']?.toString().toLowerCase() ?? '';
        final haystack = '$title $artist'.replaceAll(
          RegExp(r'[^a-z0-9\u00c0-\u024f]+'),
          ' ',
        );
        if (words.every(haystack.contains)) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) matches.putIfAbsent(id, () => row);
        }
      }
    }
    int rank(Map<String, dynamic> row) {
      final title = row['name']?.toString().toLowerCase() ?? '';
      final artist = row['artist_name']?.toString().toLowerCase() ?? '';
      if (title == clean) return 0;
      if (title.startsWith(clean)) return 1;
      if (artist == clean) return 2;
      if (artist.startsWith(clean)) return 3;
      return 4;
    }

    final rows = matches.values.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        return ((a['chart_rank'] as num?)?.toInt() ?? 9999).compareTo(
          (b['chart_rank'] as num?)?.toInt() ?? 9999,
        );
      });
    return rows.take(20).toList(growable: false);
  }

  void invalidate(DiscoverCategory category) {
    _cache.removeWhere((key, value) => key.startsWith('${category.name}:'));
    _sharedData.removeWhere(
      (key, value) => key.startsWith('${category.name}:'),
    );
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    if (_activeRequests >= 6) {
      final waiter = Completer<void>();
      _networkWaiters.add(waiter);
      await waiter.future;
    } else {
      _activeRequests++;
    }
    late http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 20));
    } finally {
      if (_networkWaiters.isNotEmpty) {
        _networkWaiters.removeAt(0).complete();
      } else {
        _activeRequests--;
      }
    }
    if (response.statusCode != 200) {
      throw Exception('Catalog request failed (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid catalog response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<DiscoverGenre>> genres(DiscoverCategory category) {
    if (isMusic(category)) {
      return Future.value(musicGenres);
    }
    final language = LocaleService.instance.effectiveLanguageCode == 'hr'
        ? 'hr-HR'
        : 'en-US';
    final key = '${category.name}:$language';
    return _genreRequests.putIfAbsent(key, () async {
      try {
        await _initialize();
        final localGenres = _cache['genres:$key'];
        if (localGenres != null) {
          return localGenres.rows
              .map(
                (g) => DiscoverGenre(
                  (g['id'] as num).toInt(),
                  g['name'].toString(),
                ),
              )
              .toList();
        }
        final shared = await _sharedCategory(category);
        final serverGenres = shared['genres:0'];
        if (serverGenres != null && serverGenres.isNotEmpty) {
          _cache['genres:$key'] = (time: DateTime.now(), rows: serverGenres);
          unawaited(_persist('genres:$key', serverGenres));
          return serverGenres
              .map(
                (g) => DiscoverGenre(
                  (g['id'] as num).toInt(),
                  g['name'].toString(),
                ),
              )
              .toList();
        }
        final saved = _cache['genres:$key'];
        if (saved != null) {
          return saved.rows
              .map(
                (g) => DiscoverGenre(
                  (g['id'] as num).toInt(),
                  g['name'].toString(),
                ),
              )
              .toList();
        }
        final data = await _get(
          Uri.parse('${TmdbService.baseUrl}/genre/${mediaType(category)}/list')
              .replace(
                queryParameters: {
                  'api_key': TmdbService.apiKey,
                  'language': language,
                },
              ),
        );
        final rows = (data['genres'] as List? ?? [])
            .whereType<Map>()
            .map((g) => Map<String, dynamic>.from(g))
            .toList();
        _cache['genres:$key'] = (time: DateTime.now(), rows: rows);
        unawaited(_persist('genres:$key', rows));
        return rows
            .map(
              (g) =>
                  DiscoverGenre((g['id'] as num).toInt(), g['name'].toString()),
            )
            .toList();
      } catch (_) {
        _genreRequests.remove(key);
        rethrow;
      }
    });
  }

  static bool _readyAlbum(Map<String, dynamic> row) =>
      row['schema_version'] == 1 &&
      row['primary_type'] == 'Album' &&
      row['secondary_types'] is List &&
      (row['secondary_types'] as List).isEmpty &&
      RegExp(r'^[0-9a-f-]{36}$').hasMatch(row['id']?.toString() ?? '') &&
      RegExp(r'^[0-9a-f-]{36}$').hasMatch(row['artist_id']?.toString() ?? '') &&
      (row['name']?.toString().isNotEmpty ?? false) &&
      (row['artist_name']?.toString().isNotEmpty ?? false);

  List<Map<String, dynamic>> _forMode(
    DiscoverCategory category,
    DiscoverMode mode,
    List<Map<String, dynamic>> rows,
  ) => category != DiscoverCategory.albums
      ? rows
      : mode == DiscoverMode.top100
      ? rows.take(100).toList()
      : mode == DiscoverMode.trending
      ? rows.take(20).toList()
      : rows;

  Future<List<Map<String, dynamic>>> load(
    DiscoverCategory category,
    DiscoverMode mode, {
    int? genreId,
    bool force = false,
  }) async {
    await _initialize();
    final modeKey = category == DiscoverCategory.albums
        ? 'studio'
        : isMusic(category)
        ? 'chart'
        : mode.name;
    final key =
        '${category.name}:$modeKey:$genreId:${(LocaleService.instance.effectiveLanguageCode == 'hr' ? 'hr-HR' : 'en-US')}';
    final cached = _cache[key];
    if (!force && cached != null) {
      if (DateTime.now().difference(cached.time) >= const Duration(hours: 24)) {
        // Show saved results immediately while a fresh request runs quietly.
        unawaited(
          _request(
            key,
            category,
            mode,
            genreId,
          ).then<void>((_) {}, onError: (Object _) {}),
        );
      }
      return _forMode(category, mode, cached.rows);
    }
    if (force) {
      _sharedData.removeWhere((key, _) => key.startsWith('${category.name}:'));
    }
    final rows = await _request(key, category, mode, genreId);
    return _forMode(category, mode, rows);
  }

  Future<List<Map<String, dynamic>>> _request(
    String key,
    DiscoverCategory category,
    DiscoverMode mode,
    int? genreId,
  ) {
    final pending = _pending[key];
    if (pending != null) {
      return pending;
    }
    final request = _fetch(category, mode, genreId)
        .then((rows) {
          _cache[key] = (time: DateTime.now(), rows: rows);
          unawaited(_persist(key, rows));
          return rows;
        })
        .whenComplete(() {
          _pending.remove(key);
        });
    _pending[key] = request;
    return request;
  }

  Future<List<Map<String, dynamic>>> _fetch(
    DiscoverCategory category,
    DiscoverMode mode,
    int? genreId,
  ) async {
    final shared = await _sharedCategory(category);
    final serverMode = category == DiscoverCategory.albums
        ? 'studio'
        : isMusic(category)
        ? 'chart'
        : mode == DiscoverMode.forYou
        ? 'trending'
        : mode.name;
    final serverRows = shared['$serverMode:${genreId ?? 0}'];
    if (serverRows != null) {
      return serverRows;
    }
    if (category == DiscoverCategory.albums) {
      // Do not fall back to a raw chart and perform slow validation on the phone.
      throw StateError(
        'This genre has not been prepared by the album cache job.',
      );
    }
    // Safe fallback while installing the backend or if a cache row is missing.
    if (isMusic(category)) {
      return _music(category, genreId);
    }
    final type = mediaType(category);
    final rows = <Map<String, dynamic>>[];
    final seen = <int>{};
    final pages = mode == DiscoverMode.top100
        ? 5
        : (mode == DiscoverMode.forYou ? 2 : 1);
    Future<List<Map<String, dynamic>>> fetchPage(int page) async {
      final path = mode == DiscoverMode.trending && genreId == null
          ? '/trending/$type/week'
          : mode == DiscoverMode.top100 && genreId == null
          ? '/$type/top_rated'
          : '/discover/$type';
      final query = <String, String>{
        'api_key': TmdbService.apiKey,
        'language': (LocaleService.instance.effectiveLanguageCode == 'hr'
            ? 'hr-HR'
            : 'en-US'),
        'page': '$page',
        'include_adult': 'false',
      };
      if (path.startsWith('/discover')) {
        query['sort_by'] = mode == DiscoverMode.top100
            ? 'vote_average.desc'
            : 'popularity.desc';
        if (genreId != null) {
          query['with_genres'] = '$genreId';
        }
        if (mode == DiscoverMode.top100) {
          query['vote_count.gte'] = type == 'movie' ? '300' : '100';
        }
      }
      final data = await _get(
        Uri.parse('${TmdbService.baseUrl}$path')
            .replace(queryParameters: query),
      );
      final results = data['results'];
      if (results is! List) {
        throw const FormatException('Invalid TMDB results');
      }
      return results
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    // Fetch page one to learn the page count, then fetch the rest concurrently.
    // TMDB may reject requests beyond total_pages for small genre lists.
    final firstPath = mode == DiscoverMode.trending && genreId == null
        ? '/trending/$type/week'
        : mode == DiscoverMode.top100 && genreId == null
        ? '/$type/top_rated'
        : '/discover/$type';
    final firstQuery = <String, String>{
      'api_key': TmdbService.apiKey,
      'language': LocaleService.instance.effectiveLanguageCode == 'hr'
          ? 'hr-HR'
          : 'en-US',
      'page': '1',
      'include_adult': 'false',
      if (firstPath.startsWith('/discover'))
        'sort_by': mode == DiscoverMode.top100
            ? 'vote_average.desc'
            : 'popularity.desc',
      if (genreId != null) 'with_genres': '$genreId',
      if (firstPath.startsWith('/discover') && mode == DiscoverMode.top100)
        'vote_count.gte': type == 'movie' ? '300' : '100',
    };
    final first = await _get(
      Uri.parse('${TmdbService.baseUrl}$firstPath')
          .replace(queryParameters: firstQuery),
    );
    if (first['results'] is! List) {
      throw const FormatException('Invalid TMDB results');
    }
    final totalPages = (first['total_pages'] as num?)?.toInt() ?? 1;
    final batches = [
      (first['results'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      ...await Future.wait([
        for (var page = 2; page <= pages && page <= totalPages; page++)
          fetchPage(page),
      ]),
    ];
    for (final batch in batches) {
      for (final item in batch) {
        final id = item['id'];
        if (id is num && seen.add(id.toInt())) {
          rows.add(item);
        }
      }
    }
    return rows.take(mode == DiscoverMode.top100 ? 100 : 40).toList();
  }

  Future<List<Map<String, dynamic>>> _music(
    DiscoverCategory category,
    int? genreId,
  ) async {
    final kind = category == DiscoverCategory.albums ? 'topalbums' : 'topsongs';
    final genre = genreId == null ? '' : '/genre=$genreId';
    final data = await _get(
      Uri.parse(
        'https://itunes.apple.com/$musicCountry/rss/$kind/limit=100$genre/json',
      ),
    );
    final feed = data['feed'];
    if (feed is! Map) {
      throw const FormatException('Invalid chart feed');
    }
    final raw = feed['entry'];
    final entries = raw is List
        ? raw
        : raw is Map
        ? [raw]
        : [];
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    String label(dynamic value) =>
        value is Map ? value['label']?.toString() ?? '' : '';
    for (final entry in entries.whereType<Map>()) {
      final idObject = entry['id'];
      final id = idObject is Map && idObject['attributes'] is Map
          ? idObject['attributes']['im:id']?.toString()
          : null;
      if (id == null || !seen.add(id)) {
        continue;
      }
      final images = entry['im:image'];
      final categoryObject = entry['category'];
      final attributes =
          categoryObject is Map && categoryObject['attributes'] is Map
          ? categoryObject['attributes'] as Map
          : <dynamic, dynamic>{};
      final date = label(entry['im:releaseDate']);
      rows.add({
        'id': id,
        'name': label(entry['im:name']),
        'artist_name': label(entry['im:artist']),
        'cover_url': images is List && images.isNotEmpty
            ? label(images.last)
            : null,
        'year': date.length >= 4 ? date.substring(0, 4) : '',
        'genre_ids': [
          if (int.tryParse(attributes['im:id']?.toString() ?? '') != null)
            int.parse(attributes['im:id'].toString()),
        ],
        'genres': [
          if (attributes['label'] != null) attributes['label'].toString(),
        ],
        'chart_rank': rows.length + 1,
        '_source': 'itunes_chart',
      });
    }
    return rows;
  }
}
