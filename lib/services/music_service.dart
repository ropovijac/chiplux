import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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

  String yearsActive({
    String present = 'Present',
    String unknown = 'Unknown',
  }) {
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

  const MusicAlbumSearchResult({
    required this.album,
    required this.score,
  });

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

  // MusicBrainz asks clients to identify themselves. For production, set a
  // contactable value at build time, for example:
  // --dart-define=MUSICBRAINZ_USER_AGENT="Chiplux/1.0 (you@example.com)"
  static const String _userAgent = String.fromEnvironment(
    'MUSICBRAINZ_USER_AGENT',
    defaultValue: 'Chiplux/1.0 (development build)',
  );

  static const Duration _minimumRequestSpacing = Duration(milliseconds: 1100);

  final Map<String, List<MusicArtist>> _artistSearchCache = {};
  final Map<String, List<MusicAlbumSearchResult>> _albumSearchCache = {};
  final Map<String, List<MusicSongSearchResult>> _songSearchCache = {};
  final Map<String, MusicArtist> _artistDetailsCache = {};
  final Map<String, List<MusicAlbum>> _discographyCache = {};
  final Map<String, MusicAlbumDetails> _albumDetailsCache = {};

  Future<void> _requestQueue = Future<void>.value();
  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<MusicArtist>> searchArtists(String query) async {
    final clean = query.trim();
    if (clean.length < 2) {
      return const [];
    }

    final cacheKey = clean.toLowerCase();
    final cached = _artistSearchCache[cacheKey];
    if (cached != null) {
      return List<MusicArtist>.unmodifiable(cached);
    }

    final data = await _getJson(
      _uri('/artist', {
        'query': clean,
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
      if (!const {'Person', 'Group', 'Orchestra', 'Choir'}.contains(artist.type)) {
        continue;
      }

      artists.add(artist);
    }

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
      _uri('/release-group', {
        'query': clean,
        'limit': '10',
        'offset': '0',
      }),
    );

    final rawGroups = List<dynamic>.from(
      data['release-groups'] ?? const [],
    );
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
      _uri('/recording', {
        'query': clean,
        'limit': '12',
        'offset': '0',
      }),
    );

    final rawRecordings = List<dynamic>.from(
      data['recordings'] ?? const [],
    );
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
        firstReleaseDate:
            release['date']?.toString().trim().isNotEmpty == true
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

  Future<MusicArtist> getArtistDetails(String artistId) async {
    final cleanId = artistId.trim();
    final cached = _artistDetailsCache[cleanId];
    if (cached != null) {
      return cached;
    }

    final data = await _getJson(
      _uri('/artist/$cleanId', {
        'inc': 'genres+artist-rels',
      }),
    );

    final artist = _parseArtist(data, includeMembers: true);
    _artistDetailsCache[cleanId] = artist;
    return artist;
  }

  Future<List<MusicAlbum>> getStudioAlbums(
    String artistId, {
    String fallbackArtistName = '',
    List<String> fallbackGenres = const [],
  }) async {
    final cleanId = artistId.trim();
    final cached = _discographyCache[cleanId];
    if (cached != null) {
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

      final rawGroups = List<dynamic>.from(
        data['release-groups'] ?? const [],
      );

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
    final completer = Completer<Map<String, dynamic>>();

    _requestQueue = _requestQueue.then((_) async {
      final elapsed = DateTime.now().difference(_lastRequestAt);
      if (elapsed < _minimumRequestSpacing) {
        await Future<void>.delayed(_minimumRequestSpacing - elapsed);
      }

      try {
        final result = await _performRequest(uri);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  Future<Map<String, dynamic>> _performRequest(Uri uri) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      _lastRequestAt = DateTime.now();

      late final http.Response response;

      try {
        response = await http
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': _userAgent,
              },
            )
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }

        throw Exception('MusicBrainz request timed out.');
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        throw Exception('MusicBrainz returned an invalid response.');
      }

      if ((response.statusCode == 503 || response.statusCode == 429) &&
          attempt == 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }

      throw Exception(
        'MusicBrainz request failed: ${response.statusCode}',
      );
    }

    throw Exception('MusicBrainz request failed.');
  }

  Uri _uri(String path, Map<String, String> query) {
    return Uri.https(
      _host,
      '$_basePath$path',
      <String, String>{...query, 'fmt': 'json'},
    );
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
      final name = map['name']?.toString() ??
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
