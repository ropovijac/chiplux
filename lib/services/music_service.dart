import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MusicArtistPhoto {
  final String url;
  final String sourceUrl;
  final String? bannerUrl;
  final String credit;
  final String license;
  final String licenseUrl;
  const MusicArtistPhoto({
    required this.url,
    required this.sourceUrl,
    required this.credit,
    required this.license,
    required this.licenseUrl,
    this.bannerUrl,
  });
  Map<String, dynamic> toJson() => {
    'url': url,
    'sourceUrl': sourceUrl,
    'credit': credit,
    'license': license,
    'licenseUrl': licenseUrl,
    'bannerUrl': bannerUrl,
  };
  factory MusicArtistPhoto.fromJson(Map<String, dynamic> data) =>
      MusicArtistPhoto(
        url: data['url'] as String,
        sourceUrl: data['sourceUrl'] as String,
        credit: data['credit'] as String,
        license: data['license'] as String,
        licenseUrl: data['licenseUrl'] as String,
        bannerUrl: data['bannerUrl']?.toString(),
      );
}

class MusicCatalogException implements Exception {
  final int status;
  const MusicCatalogException(this.status);
  @override
  String toString() => 'MusicCatalogException(status: $status)';
}

class MusicMember {
  final String id;
  final String name;
  final List<String> roles;
  final String? beginDate;
  final String? endDate;
  final bool ended;

  const MusicMember({
    required this.id,
    required this.name,
    this.roles = const [],
    this.beginDate,
    this.endDate,
    this.ended = false,
  });

  bool get isCurrent => !ended && (endDate == null || endDate!.isEmpty);

  String get roleLabel => roles.join(', ');
}

class MusicArtist {
  final String id;
  final String name;
  final String type;
  final String disambiguation;
  final String? country;
  final String? beginDate;
  final String? endDate;
  final bool ended;
  final int score;
  final List<String> genres;
  final List<MusicMember> members;

  const MusicArtist({
    required this.id,
    required this.name,
    required this.type,
    this.disambiguation = '',
    this.country,
    this.beginDate,
    this.endDate,
    this.ended = false,
    this.score = 0,
    this.genres = const [],
    this.members = const [],
  });

  bool get isGroupLike =>
      type == 'Group' || type == 'Orchestra' || type == 'Choir';

  String get displayType {
    switch (type) {
      case 'Person':
        return 'Musician';
      case 'Group':
        return 'Band / Group';
      case 'Orchestra':
        return 'Orchestra';
      case 'Choir':
        return 'Choir';
      default:
        return 'Music Artist';
    }
  }

  String yearsActive({String present = 'Present', String unknown = 'Unknown'}) {
    final beginYear = _year(beginDate);
    final endYear = _year(endDate);

    if (beginYear != null && endYear != null) {
      return '$beginYear–$endYear';
    }

    if (beginYear != null && !ended) {
      return '$beginYear–$present';
    }

    if (beginYear != null) {
      return beginYear;
    }

    if (endYear != null) {
      return endYear;
    }

    return unknown;
  }

  Map<String, dynamic> toSearchMap() {
    return {
      '_chiplux_source': 'musicbrainz',
      'id': id,
      'name': name,
      'artist_type': type,
      'music_display_type': displayType,
      'disambiguation': disambiguation,
      'country': country,
      'begin_date': beginDate,
      'end_date': endDate,
      'ended': ended,
      'score': score,
    };
  }

  static String? _year(String? date) {
    final clean = date?.trim() ?? '';
    if (clean.length < 4) {
      return null;
    }

    final value = clean.substring(0, 4);
    return int.tryParse(value) == null ? null : value;
  }
}

class MusicAlbum {
  final String id;
  final String title;
  final String artistId;
  final String artistName;
  final String firstReleaseDate;
  final String primaryType;
  final List<String> secondaryTypes;
  final List<String> genres;

  const MusicAlbum({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    this.firstReleaseDate = '',
    this.primaryType = 'Album',
    this.secondaryTypes = const [],
    this.genres = const [],
  });

  String get year {
    if (firstReleaseDate.length < 4) {
      return '';
    }

    return firstReleaseDate.substring(0, 4);
  }

  String get coverUrl =>
      'https://coverartarchive.org/release-group/$id/front-250';
}

class MusicTrack {
  final String id;
  final String title;
  final int discNumber;
  final int position;
  final String number;
  final int? durationMs;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.discNumber,
    required this.position,
    required this.number,
    this.durationMs,
  });

  String get durationLabel {
    final milliseconds = durationMs;
    if (milliseconds == null || milliseconds <= 0) {
      return '';
    }

    final totalSeconds = (milliseconds / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class MusicAlbumDetails {
  final MusicAlbum album;
  final String? releaseId;
  final List<MusicTrack> tracks;

  const MusicAlbumDetails({
    required this.album,
    required this.releaseId,
    required this.tracks,
  });

  int get knownRuntimeMs {
    int total = 0;
    for (final track in tracks) {
      final duration = track.durationMs;
      if (duration != null && duration > 0) {
        total += duration;
      }
    }
    return total;
  }

  String get runtimeLabel {
    final milliseconds = knownRuntimeMs;
    if (milliseconds <= 0) {
      return '';
    }

    final totalMinutes = (milliseconds / 60000).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours <= 0) {
      return '${totalMinutes}m';
    }

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }
}

class MusicAlbumSearchResult {
  final MusicAlbum album;
  final int score;

  const MusicAlbumSearchResult({required this.album, required this.score});

  Map<String, dynamic> toSearchMap() {
    return {
      '_chiplux_source': 'musicbrainz',
      '_music_result_type': 'album',
      '_music_album': album,
      'name': album.title,
      'music_display_type': 'Album',
      'artist_name': album.artistName,
      'year': album.year,
      'cover_url': album.coverUrl,
      'score': score,
    };
  }
}

class MusicSongSearchResult {
  final MusicTrack track;
  final MusicAlbum album;
  final int score;

  const MusicSongSearchResult({
    required this.track,
    required this.album,
    required this.score,
  });

  Map<String, dynamic> toSearchMap() {
    return {
      '_chiplux_source': 'musicbrainz',
      '_music_result_type': 'song',
      '_music_album': album,
      '_music_track_id': track.id,
      'name': track.title,
      'music_display_type': 'Song',
      'artist_name': album.artistName,
      'album_title': album.title,
      'year': album.year,
      'cover_url': album.coverUrl,
      'duration_label': track.durationLabel,
      'score': score,
    };
  }
}

class MusicService {
  MusicService._();

  static final MusicService instance = MusicService._();

  static const String _host = 'musicbrainz.org';
  static const String _basePath = '/ws/2';

  final Map<String, List<MusicArtist>> _artistSearchCache = {};
  final Map<String, List<MusicAlbumSearchResult>> _albumSearchCache = {};
  final Map<String, List<MusicSongSearchResult>> _songSearchCache = {};
  final Map<String, MusicArtist> _artistDetailsCache = {};
  final Map<String, List<MusicAlbum>> _discographyCache = {};
  final Map<String, MusicAlbumDetails> _albumDetailsCache = {};

  final _httpClient = http.Client();
  int _requestSerial = 0;
  void _trace(String message) {
    if (kDebugMode) {
      debugPrint('[ChipluxMusic] $message');
    }
  }

  Future<Map<String, dynamic>> _callCatalog(Map<String, dynamic> body) async {
    const base = String.fromEnvironment('SUPABASE_URL');
    const clientKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    final parsed = Uri.tryParse(base);
    final number = ++_requestSerial;
    final operation = body['operation']?.toString() ?? 'unknown';
    _trace(
      'request=$number operation=$operation host=${parsed?.host ?? "missing"} keyConfigured=${clientKey.isNotEmpty}',
    );
    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host.isEmpty ||
        clientKey.isEmpty) {
      _trace('request=$number configuration-invalid');
      throw StateError('Music catalog URL/client configuration missing');
    }
    final uri = parsed.replace(
      path:
          '${parsed.path.replaceAll(RegExp(r"/+$"), "")}/functions/v1/music-catalog',
      query: null,
      fragment: null,
    );
    final watch = Stopwatch()..start();
    try {
      _trace('request=$number http-start');
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'apikey': clientKey},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      _trace(
        'request=$number http-status=${response.statusCode} elapsedMs=${watch.elapsedMilliseconds}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MusicCatalogException(response.statusCode);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Invalid music catalog response');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      _trace(
        'request=$number http-error=${error.runtimeType} elapsedMs=${watch.elapsedMilliseconds}',
      );
      rethrow;
    }
  }

  final _jsonRequests = <String, Future<Map<String, dynamic>>>{};
  final _jsonMemory = <String, Map<String, dynamic>>{};
  final _photoPool = _MusicPhotoPool();
  MusicArtist? cachedArtist(String id) => _artistDetailsCache[id];
  MusicAlbumDetails? cachedAlbumDetails(String id) => _albumDetailsCache[id];

  final _photoRequests = <String, Future<MusicArtistPhoto?>>{};
  Future<MusicArtistPhoto?> getArtistPhoto(String artistId) {
    return _photoRequests.putIfAbsent(
      artistId,
      () => _loadArtistPhoto(artistId).catchError((Object _) {
        _photoRequests.remove(artistId);
        return null;
      }),
    );
  }

  Future<Map<String, dynamic>> _fetchPhoto(String artistId) => _photoPool.run(
    () => _callCatalog({'operation': 'photo', 'artist_id': artistId}),
  );
  Future<MusicArtistPhoto?> _loadArtistPhoto(String artistId) async {
    if (!RegExp(r'^[a-f0-9-]{36}$', caseSensitive: false).hasMatch(artistId)) {
      return null;
    }
    final preferences = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 2),
    );
    final key = 'chiplux_artist_photo_v5:$artistId';
    final saved = preferences.getString(key);
    if (saved != null) {
      try {
        final decoded = jsonDecode(saved) as Map;
        if (DateTime.now().difference(
              DateTime.parse(decoded['time'] as String),
            ) <
            const Duration(days: 30)) {
          return MusicArtistPhoto.fromJson(
            Map<String, dynamic>.from(decoded['photo'] as Map),
          );
        }
      } catch (_) {
        /* Retry malformed cache. */
      }
    }
    final payload = await _fetchPhoto(artistId);
    final data = payload['data'];
    if (data is! Map) {
      _photoRequests.remove(artistId);
      return null;
    }
    final photo = MusicArtistPhoto.fromJson(Map<String, dynamic>.from(data));
    unawaited(
      preferences
          .setString(
            key,
            jsonEncode({
              'time': DateTime.now().toIso8601String(),
              'photo': photo.toJson(),
            }),
          )
          .then<void>((_) {}, onError: (Object _) {}),
    );
    return photo;
  }

  final _songMappings = <String, Future<Map<String, dynamic>?>>{};
  final _songPool = _MusicPhotoPool();
  Future<Map<String, dynamic>?> resolveChartSong(
    Map<String, dynamic> item,
  ) async {
    final key = '${item['id']}:${item['name']}:${item['artist_name']}';
    final mapping = await _songMappings.putIfAbsent(
      key,
      () => _resolveSongMapping(key, item).catchError((
        Object error,
        StackTrace stack,
      ) {
        _songMappings.remove(key);
        Error.throwWithStackTrace(error, stack);
      }),
    );
    return mapping == null ? null : {...item, 'album_mapping': mapping};
  }

  Future<Map<String, dynamic>?> _resolveSongMapping(
    String key,
    Map<String, dynamic> item,
  ) async {
    // Read local matches before acquiring a remote-request slot.
    final diskKey = 'chiplux_song_album_v1:$key';
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      /* Metadata can still load if local storage is unavailable. */
    }
    final saved = preferences?.getString(diskKey);
    if (saved != null) {
      try {
        final record = jsonDecode(saved) as Map;
        if (DateTime.now().difference(
              DateTime.parse(record['time'] as String),
            ) <
            const Duration(days: 30)) {
          return Map<String, dynamic>.from(record['mapping'] as Map);
        }
      } catch (_) {
        /* Fetch again if the cached mapping is malformed. */
      }
    }
    return _songPool.run(() async {
      final payload = await _callCatalog({
        'operation': 'resolve_song',
        'title': item['name']?.toString() ?? '',
        'artist': item['artist_name']?.toString() ?? '',
      });
      final data = payload['data'];
      if (data is! Map) {
        return null;
      }
      final mapping = Map<String, dynamic>.from(data);
      if (preferences != null) {
        unawaited(
          preferences
              .setString(
                diskKey,
                jsonEncode({
                  'time': DateTime.now().toIso8601String(),
                  'mapping': mapping,
                }),
              )
              .then<void>((_) {}, onError: (Object _) {}),
        );
      }
      return mapping;
    });
  }

  Future<List<Map<String, dynamic>>> prepareChartSongs(
    List<Map<String, dynamic>> items,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      final resolved = await resolveChartSong(item);
      if (resolved != null) {
        rows.add(resolved);
      }
    }
    return rows;
  }

  MusicAlbum albumFromMapping(Map mapping) => MusicAlbum(
    id: mapping['album_id'].toString(),
    title: mapping['album_title'].toString(),
    artistId: mapping['artist_id']?.toString() ?? '',
    artistName: mapping['artist_name']?.toString() ?? '',
    firstReleaseDate: mapping['release_date']?.toString() ?? '',
    primaryType: 'Album',
    secondaryTypes: const [],
  );

  Future<List<MusicArtist>> searchArtists(String query) async {
    final clean = query.trim();
    if (clean.length < 2) {
      return const [];
    }

    _trace('artist-search start chars=${clean.length}');
    final cacheKey = clean.toLowerCase();
    final cached = _artistSearchCache[cacheKey];
    if (cached != null) {
      return List<MusicArtist>.unmodifiable(cached);
    }

    final data = await _getJson(
      _uri('/artist', {
        'query': clean.contains(':')
            ? clean
            : 'artist:"${clean.replaceAll(RegExp(r'[\"\\]'), ' ')}"',
        'limit': '12',
        'offset': '0',
      }),
    );

    final rawArtists = List<dynamic>.from(data['artists'] ?? const []);
    final artists = <MusicArtist>[];

    for (final raw in rawArtists) {
      if (raw is! Map) {
        continue;
      }

      final artist = _parseArtist(Map<String, dynamic>.from(raw));

      // Chiplux's People search is for real musicians and musical groups.
      // Character/Other MusicBrainz artist types are intentionally excluded.
      if (!const {
        'Person',
        'Group',
        'Orchestra',
        'Choir',
      }.contains(artist.type)) {
        continue;
      }

      artists.add(artist);
    }

    final exact = artists
        .where((artist) => artist.name.toLowerCase() == clean.toLowerCase())
        .toList();
    if (exact.isNotEmpty) {
      final top = exact.first;
      // Start the most likely photo before search cards enqueue other matches.
      unawaited(getArtistPhoto(top.id));
      unawaited(
        getArtistDetails(top.id).then<void>((_) {}, onError: (Object _) {}),
      );
    }
    _trace(
      'artist-search parsed=${artists.length} groups=${artists.where((artist) => artist.isGroupLike).length}',
    );
    _artistSearchCache[cacheKey] = artists;
    return List<MusicArtist>.unmodifiable(artists);
  }

  Future<List<MusicArtist>> searchMusicians(String query) async {
    final artists = await searchArtists(query);
    return artists
        .where((artist) => artist.type == 'Person')
        .toList(growable: false);
  }

  Future<List<MusicArtist>> searchGroups(String query) async {
    final artists = await searchArtists(query);
    return artists
        .where((artist) => artist.isGroupLike)
        .toList(growable: false);
  }

  Future<List<MusicAlbumSearchResult>> searchStudioAlbums(String query) async {
    final clean = query.trim();
    if (clean.length < 2) {
      return const [];
    }

    final cacheKey = clean.toLowerCase();
    final cached = _albumSearchCache[cacheKey];
    if (cached != null) {
      return List<MusicAlbumSearchResult>.unmodifiable(cached);
    }

    final data = await _getJson(
      _uri('/release-group', {'query': clean, 'limit': '10', 'offset': '0'}),
    );

    final rawGroups = List<dynamic>.from(data['release-groups'] ?? const []);
    final results = <MusicAlbumSearchResult>[];
    final seen = <String>{};

    for (final raw in rawGroups) {
      if (raw is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(raw);
      final id = map['id']?.toString().trim() ?? '';
      final title = map['title']?.toString().trim() ?? '';
      final primaryType = map['primary-type']?.toString() ?? '';
      final secondaryTypes = _stringList(map['secondary-types']);

      // Chiplux currently supports studio albums only.
      if (id.isEmpty ||
          title.isEmpty ||
          primaryType != 'Album' ||
          secondaryTypes.isNotEmpty ||
          !seen.add(id)) {
        continue;
      }

      final artistName = _artistCreditName(map['artist-credit']);
      final artistId = _firstArtistId(map['artist-credit']);

      results.add(
        MusicAlbumSearchResult(
          album: MusicAlbum(
            id: id,
            title: title,
            artistId: artistId,
            artistName: artistName.isEmpty ? 'Unknown' : artistName,
            firstReleaseDate:
                map['first-release-date']?.toString().trim() ?? '',
            primaryType: primaryType,
            secondaryTypes: secondaryTypes,
            genres: _parseGenres(map['genres']),
          ),
          score: _asInt(map['score']) ?? 0,
        ),
      );
    }

    _albumSearchCache[cacheKey] = results;
    return List<MusicAlbumSearchResult>.unmodifiable(results);
  }

  Future<List<MusicSongSearchResult>> searchSongs(String query) async {
    final clean = query.trim();
    if (clean.length < 2) {
      return const [];
    }

    final cacheKey = clean.toLowerCase();
    final cached = _songSearchCache[cacheKey];
    if (cached != null) {
      return List<MusicSongSearchResult>.unmodifiable(cached);
    }

    final data = await _getJson(
      _uri('/recording', {'query': clean, 'limit': '12', 'offset': '0'}),
    );

    final rawRecordings = List<dynamic>.from(data['recordings'] ?? const []);
    final results = <MusicSongSearchResult>[];
    final seen = <String>{};

    for (final raw in rawRecordings) {
      if (raw is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(raw);
      final recordingId = map['id']?.toString().trim() ?? '';
      final title = map['title']?.toString().trim() ?? '';

      if (recordingId.isEmpty || title.isEmpty || !seen.add(recordingId)) {
        continue;
      }

      final releases = List<dynamic>.from(map['releases'] ?? const []);
      final studioCandidates = <Map<String, dynamic>>[];

      for (final rawRelease in releases) {
        if (rawRelease is! Map) {
          continue;
        }

        final release = Map<String, dynamic>.from(rawRelease);
        if (release['status']?.toString() != 'Official' ||
            release['release-group'] is! Map) {
          continue;
        }

        final releaseGroup = Map<String, dynamic>.from(
          release['release-group'] as Map,
        );

        if (releaseGroup['primary-type']?.toString() != 'Album' ||
            _stringList(releaseGroup['secondary-types']).isNotEmpty) {
          continue;
        }

        studioCandidates.add(release);
      }

      if (studioCandidates.isEmpty) {
        continue;
      }

      studioCandidates.sort((a, b) {
        final aDate = a['date']?.toString() ?? '';
        final bDate = b['date']?.toString() ?? '';

        if (aDate.isEmpty && bDate.isNotEmpty) {
          return 1;
        }
        if (bDate.isEmpty && aDate.isNotEmpty) {
          return -1;
        }
        return aDate.compareTo(bDate);
      });

      final release = studioCandidates.first;
      final releaseGroup = Map<String, dynamic>.from(
        release['release-group'] as Map,
      );
      final albumId = releaseGroup['id']?.toString().trim() ?? '';
      final albumTitle = release['title']?.toString().trim() ?? '';

      if (albumId.isEmpty || albumTitle.isEmpty) {
        continue;
      }

      final recordingArtistName = _artistCreditName(map['artist-credit']);
      final recordingArtistId = _firstArtistId(map['artist-credit']);
      final releaseArtistName = _artistCreditName(release['artist-credit']);
      final releaseArtistId = _firstArtistId(release['artist-credit']);

      final artistName = releaseArtistName.isNotEmpty
          ? releaseArtistName
          : recordingArtistName;
      final artistId = releaseArtistId.isNotEmpty
          ? releaseArtistId
          : recordingArtistId;

      final album = MusicAlbum(
        id: albumId,
        title: albumTitle,
        artistId: artistId,
        artistName: artistName.isEmpty ? 'Unknown' : artistName,
        firstReleaseDate: release['date']?.toString().trim().isNotEmpty == true
            ? release['date'].toString().trim()
            : map['first-release-date']?.toString().trim() ?? '',
        primaryType: 'Album',
        secondaryTypes: const [],
      );

      results.add(
        MusicSongSearchResult(
          track: MusicTrack(
            id: recordingId,
            title: title,
            discNumber: 1,
            position: 0,
            number: '',
            durationMs: _asInt(map['length']),
          ),
          album: album,
          score: _asInt(map['score']) ?? 0,
        ),
      );
    }

    _songSearchCache[cacheKey] = results;
    return List<MusicSongSearchResult>.unmodifiable(results);
  }

  Future<Map<String, dynamic>> getMemberCredits(String artistId) => _getJson(
    _uri('/artist/${artistId.trim()}', {
      'inc': 'artist-rels+recording-rels+work-rels+release-group-rels',
    }),
  );

  final _artistDetailsRequests = <String, Future<MusicArtist>>{};
  Future<MusicArtist> getArtistDetails(String artistId) {
    final id = artistId.trim();
    return _artistDetailsRequests.putIfAbsent(
      id,
      () => _fetchArtistDetails(id).whenComplete(() {
        _artistDetailsRequests.remove(id);
      }),
    );
  }

  Future<MusicArtist> _fetchArtistDetails(String artistId) async {
    final cleanId = artistId.trim();
    final cached = _artistDetailsCache[cleanId];
    if (cached != null) {
      return cached;
    }

    final data = await _getJson(
      _uri('/artist/$cleanId', {'inc': 'genres+artist-rels+url-rels'}),
    );

    final artist = _parseArtist(data, includeMembers: true);
    _artistDetailsCache[cleanId] = artist;
    return artist;
  }

  Future<List<MusicAlbum>> getStudioAlbums(
    String artistId, {
    String fallbackArtistName = '',
    List<String> fallbackGenres = const [],
    void Function(List<MusicAlbum>)? onPage,
  }) async {
    final cleanId = artistId.trim();
    final cached = _discographyCache[cleanId];
    if (cached != null) {
      onPage?.call(List<MusicAlbum>.unmodifiable(cached));
      return List<MusicAlbum>.unmodifiable(cached);
    }

    const limit = 100;
    int offset = 0;
    int totalCount = 0;
    final albums = <MusicAlbum>[];
    final seenIds = <String>{};

    do {
      final data = await _getJson(
        _uri('/release-group', {
          'artist': cleanId,
          'type': 'album',
          'inc': 'artist-credits+genres',
          'limit': '$limit',
          'offset': '$offset',
        }),
      );

      final rawGroups = List<dynamic>.from(data['release-groups'] ?? const []);

      totalCount = _asInt(data['release-group-count']) ?? rawGroups.length;

      for (final raw in rawGroups) {
        if (raw is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(raw);
        final id = map['id']?.toString().trim() ?? '';
        final title = map['title']?.toString().trim() ?? '';
        final primaryType = map['primary-type']?.toString() ?? '';
        final secondaryTypes = _stringList(map['secondary-types']);

        // MusicBrainz does not expose a dedicated "studio album" flag.
        // The closest reliable definition is primary type Album with no
        // secondary type (so Live, Compilation, Remix, Soundtrack, etc. are
        // excluded). EPs/Singles are excluded by type=album above.
        if (id.isEmpty ||
            title.isEmpty ||
            primaryType != 'Album' ||
            secondaryTypes.isNotEmpty ||
            !seenIds.add(id)) {
          continue;
        }

        final creditedArtist = _artistCreditName(map['artist-credit']);
        final releaseGroupGenres = _parseGenres(map['genres']);
        final genres = releaseGroupGenres.isNotEmpty
            ? releaseGroupGenres
            : List<String>.from(fallbackGenres);

        albums.add(
          MusicAlbum(
            id: id,
            title: title,
            artistId: cleanId,
            artistName: creditedArtist.isNotEmpty
                ? creditedArtist
                : fallbackArtistName,
            firstReleaseDate:
                map['first-release-date']?.toString().trim() ?? '',
            primaryType: primaryType,
            secondaryTypes: secondaryTypes,
            genres: genres,
          ),
        );
      }

      onPage?.call(List<MusicAlbum>.unmodifiable(albums));
      offset += rawGroups.length;

      if (rawGroups.isEmpty) {
        break;
      }
    } while (offset < totalCount);

    albums.sort((a, b) {
      final aDate = a.firstReleaseDate;
      final bDate = b.firstReleaseDate;

      if (aDate.isEmpty && bDate.isNotEmpty) {
        return 1;
      }
      if (bDate.isEmpty && aDate.isNotEmpty) {
        return -1;
      }

      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) {
        return dateCompare;
      }

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    _discographyCache[cleanId] = albums;
    return List<MusicAlbum>.unmodifiable(albums);
  }

  Future<MusicAlbumDetails> getAlbumDetails(MusicAlbum album) async {
    final cached = _albumDetailsCache[album.id];
    if (cached != null) {
      return cached;
    }

    final data = await _getJson(
      _uri('/release', {
        'release-group': album.id,
        'status': 'official',
        'inc': 'media+recordings+artist-credits+release-groups',
        'limit': '100',
        'offset': '0',
      }),
    );

    final rawReleases = List<dynamic>.from(data['releases'] ?? const []);
    final candidates = <Map<String, dynamic>>[];

    for (final raw in rawReleases) {
      if (raw is! Map) {
        continue;
      }

      final release = Map<String, dynamic>.from(raw);
      if (_releaseTrackCount(release) > 0) {
        candidates.add(release);
      }
    }

    candidates.sort((a, b) {
      final aDate = a['date']?.toString() ?? '';
      final bDate = b['date']?.toString() ?? '';

      if (aDate.isEmpty && bDate.isNotEmpty) {
        return 1;
      }
      if (bDate.isEmpty && aDate.isNotEmpty) {
        return -1;
      }

      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) {
        return dateCompare;
      }

      // If several territories released the album on the same day, prefer
      // the edition with fewer tracks so bonus/deluxe tracks are less likely.
      return _releaseTrackCount(a).compareTo(_releaseTrackCount(b));
    });

    if (candidates.isEmpty) {
      final empty = MusicAlbumDetails(
        album: album,
        releaseId: null,
        tracks: const [],
      );
      _albumDetailsCache[album.id] = empty;
      return empty;
    }

    final selected = candidates.first;
    final tracks = <MusicTrack>[];
    final media = List<dynamic>.from(selected['media'] ?? const []);

    int fallbackDisc = 0;
    for (final rawMedium in media) {
      if (rawMedium is! Map) {
        continue;
      }

      fallbackDisc++;
      final medium = Map<String, dynamic>.from(rawMedium);
      final discNumber = _asInt(medium['position']) ?? fallbackDisc;
      final rawTracks = List<dynamic>.from(medium['tracks'] ?? const []);

      int fallbackPosition = 0;
      for (final rawTrack in rawTracks) {
        if (rawTrack is! Map) {
          continue;
        }

        fallbackPosition++;
        final track = Map<String, dynamic>.from(rawTrack);
        final recording = track['recording'] is Map
            ? Map<String, dynamic>.from(track['recording'] as Map)
            : const <String, dynamic>{};

        final id = recording['id']?.toString().trim().isNotEmpty == true
            ? recording['id'].toString()
            : track['id']?.toString() ??
                  '${album.id}:$discNumber:$fallbackPosition';

        final title = track['title']?.toString().trim().isNotEmpty == true
            ? track['title'].toString().trim()
            : recording['title']?.toString().trim() ?? 'Unknown';

        final duration = _asInt(track['length']) ?? _asInt(recording['length']);

        tracks.add(
          MusicTrack(
            id: id,
            title: title,
            discNumber: discNumber,
            position: _asInt(track['position']) ?? fallbackPosition,
            number: track['number']?.toString() ?? '$fallbackPosition',
            durationMs: duration,
          ),
        );
      }
    }

    final details = MusicAlbumDetails(
      album: album,
      releaseId: selected['id']?.toString(),
      tracks: tracks,
    );

    _albumDetailsCache[album.id] = details;
    return details;
  }

  void clearMemoryCache() {
    _jsonMemory.clear();
    _artistSearchCache.clear();
    _albumSearchCache.clear();
    _songSearchCache.clear();
    _artistDetailsCache.clear();
    _discographyCache.clear();
    _albumDetailsCache.clear();
  }

  MusicArtist _parseArtist(
    Map<String, dynamic> map, {
    bool includeMembers = false,
  }) {
    final lifeSpan = map['life-span'] is Map
        ? Map<String, dynamic>.from(map['life-span'] as Map)
        : const <String, dynamic>{};

    final members = <MusicMember>[];

    if (includeMembers) {
      final relations = List<dynamic>.from(map['relations'] ?? const []);

      for (final raw in relations) {
        if (raw is! Map) {
          continue;
        }

        final relation = Map<String, dynamic>.from(raw);
        if (relation['type']?.toString() != 'member of band' ||
            relation['artist'] is! Map) {
          continue;
        }

        final member = Map<String, dynamic>.from(relation['artist'] as Map);
        final id = member['id']?.toString().trim() ?? '';
        final name = member['name']?.toString().trim() ?? '';

        if (id.isEmpty || name.isEmpty) {
          continue;
        }

        members.add(
          MusicMember(
            id: id,
            name: name,
            roles: _stringList(relation['attributes']),
            beginDate: relation['begin']?.toString(),
            endDate: relation['end']?.toString(),
            ended: relation['ended'] == true,
          ),
        );
      }

      members.sort((a, b) {
        if (a.isCurrent != b.isCurrent) {
          return a.isCurrent ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    return MusicArtist(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown',
      type: map['type']?.toString() ?? 'Other',
      disambiguation: map['disambiguation']?.toString() ?? '',
      country: map['country']?.toString(),
      beginDate: lifeSpan['begin']?.toString(),
      endDate: lifeSpan['end']?.toString(),
      ended: lifeSpan['ended'] == true,
      score: _asInt(map['score']) ?? 0,
      genres: _parseGenres(map['genres']),
      members: members,
    );
  }

  List<String> _parseGenres(dynamic raw) {
    if (raw is! List) {
      return const [];
    }

    final genres = <({String name, int count})>[];

    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(item);
      final name = map['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        continue;
      }

      genres.add((name: name, count: _asInt(map['count']) ?? 0));
    }

    genres.sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return genres.map((item) => item.name).toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) {
    final key = uri.toString();
    final saved = _jsonMemory[key];
    if (saved != null) {
      _trace('metadata memory-hit path=${uri.path}');
      return Future.value(saved);
    }
    return _jsonRequests.putIfAbsent(
      key,
      () => _readJson(uri).whenComplete(() {
        _jsonRequests.remove(key);
      }),
    );
  }

  Future<Map<String, dynamic>> _readJson(Uri uri) async {
    final key = uri.toString();
    _trace('metadata cache-start path=${uri.path}');
    final diskKey = 'chiplux_music_json_v1:${Uri.encodeComponent(key)}';
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      _trace('metadata preferences-ready path=${uri.path}');
      final saved = preferences.getString(diskKey);
      if (saved != null) {
        final record = jsonDecode(saved) as Map;
        if (DateTime.now().difference(
              DateTime.parse(record['time'] as String),
            ) <
            const Duration(days: 1)) {
          final data = Map<String, dynamic>.from(record['data'] as Map);
          _trace('metadata disk-hit path=${uri.path}');
          _jsonMemory[key] = data;
          return data;
        }
      }
    } catch (error) {
      _trace('metadata cache-error=${error.runtimeType}');
    }
    final query = Map<String, String>.from(uri.queryParameters)..remove('fmt');
    final payload = await _callCatalog({
      'operation': 'musicbrainz',
      'path': uri.path.substring(_basePath.length),
      'query': query,
    });
    final raw = payload['data'];
    if (raw is! Map) {
      throw const FormatException('Invalid music catalog response');
    }
    final data = Map<String, dynamic>.from(raw);
    _jsonMemory[key] = data;
    if (preferences != null) {
      unawaited(
        preferences
            .setString(
              diskKey,
              jsonEncode({
                'time': DateTime.now().toIso8601String(),
                'data': data,
              }),
            )
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
    return data;
  }

  Uri _uri(String path, Map<String, String> query) {
    return Uri.https(_host, '$_basePath$path', <String, String>{
      ...query,
      'fmt': 'json',
    });
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _artistCreditName(dynamic raw) {
    if (raw is! List) {
      return '';
    }

    final buffer = StringBuffer();

    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(item);
      final name =
          map['name']?.toString() ??
          (map['artist'] is Map
              ? (map['artist'] as Map)['name']?.toString()
              : null) ??
          '';

      buffer.write(name);
      buffer.write(map['joinphrase']?.toString() ?? '');
    }

    return buffer.toString().trim();
  }

  static String _firstArtistId(dynamic raw) {
    if (raw is! List) {
      return '';
    }

    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      final artist = item['artist'];
      if (artist is! Map) {
        continue;
      }

      final id = artist['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) {
        return id;
      }
    }

    return '';
  }

  static int _releaseTrackCount(Map<String, dynamic> release) {
    final media = release['media'];
    if (media is! List) {
      return 0;
    }

    int count = 0;
    for (final rawMedium in media) {
      if (rawMedium is! Map) {
        continue;
      }

      final medium = Map<String, dynamic>.from(rawMedium);
      final tracks = medium['tracks'];
      if (tracks is List && tracks.isNotEmpty) {
        count += tracks.length;
      } else {
        count += _asInt(medium['track-count']) ?? 0;
      }
    }

    return count;
  }
}

// Limit parallel photo lookups without making every image wait for one queue.
class _MusicPhotoPool {
  int _active = 0;
  final _waiting = <Completer<void>>[];
  Future<T> run<T>(Future<T> Function() task) async {
    if (_active >= 2) {
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _active++;
    }
    try {
      return await task();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }
}
