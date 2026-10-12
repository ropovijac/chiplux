import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'music_service.dart';


class MusicLibraryEntry {
  final String entityType;
  final String entityId;
  final String artistId;
  final String artistName;
  final String? albumId;
  final String? albumTitle;
  final String title;
  final String releaseYear;
  final String? coverUrl;
  final int durationMs;
  final String? trackNumber;
  final int? discNumber;
  final bool isListened;
  final bool isFavorite;
  final int? rating;
  final DateTime? listenedAt;
  final DateTime? ratedAt;
  final DateTime? updatedAt;
  final List<String> genres;
  final String? libraryStatus;

  const MusicLibraryEntry({
    required this.entityType,
    required this.entityId,
    required this.artistId,
    required this.artistName,
    required this.albumId,
    required this.albumTitle,
    required this.title,
    required this.releaseYear,
    required this.coverUrl,
    required this.durationMs,
    required this.trackNumber,
    required this.discNumber,
    required this.isListened,
    required this.isFavorite,
    required this.rating,
    required this.listenedAt,
    required this.ratedAt,
    required this.updatedAt,
    required this.genres,
    required this.libraryStatus,
  });

  bool get isAlbum => entityType == 'album';
  bool get isTrack => entityType == 'track';
  bool get isPlanned => isAlbum && libraryStatus == 'plan';
  bool get isDropped => isAlbum && libraryStatus == 'dropped';

  int? get ratingStars {
    final value = rating;
    if (value == null) return null;
    return (value / 2).round().clamp(1, 5).toInt();
  }

  int get runtimeMinutes => durationMs <= 0 ? 0 : (durationMs / 60000).round();

  MusicAlbum toAlbum() {
    final resolvedAlbumId = isAlbum ? entityId : (albumId ?? '');
    final resolvedAlbumTitle = isAlbum ? title : (albumTitle ?? title);

    return MusicAlbum(
      id: resolvedAlbumId,
      title: resolvedAlbumTitle,
      artistId: artistId,
      artistName: artistName,
      firstReleaseDate: releaseYear,
      genres: genres,
    );
  }

  factory MusicLibraryEntry.fromRow(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic value) {
      final text = value?.toString();
      return text == null || text.isEmpty ? null : DateTime.tryParse(text);
    }

    final rawGenres = row['genre_names'];
    final genres = rawGenres is List
        ? rawGenres
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList()
        : <String>[];

    return MusicLibraryEntry(
      entityType: row['entity_type']?.toString() ?? '',
      entityId: row['entity_id']?.toString() ?? '',
      artistId: row['artist_id']?.toString() ?? '',
      artistName: row['artist_name']?.toString() ?? '',
      albumId: row['album_id']?.toString(),
      albumTitle: row['album_title']?.toString(),
      title: row['title']?.toString() ?? 'Unknown',
      releaseYear: row['release_year']?.toString() ?? '',
      coverUrl: row['cover_url']?.toString(),
      durationMs: row['duration_ms'] is num ? (row['duration_ms'] as num).toInt() : 0,
      trackNumber: row['track_number']?.toString(),
      discNumber: row['disc_number'] is num ? (row['disc_number'] as num).toInt() : null,
      isListened: row['is_listened'] == true,
      isFavorite: row['is_favorite'] == true,
      rating: row['rating'] is num ? (row['rating'] as num).toInt() : null,
      listenedAt: parseDate(row['listened_at']),
      ratedAt: parseDate(row['rated_at']),
      updatedAt: parseDate(row['updated_at']),
      genres: genres,
      libraryStatus: row['library_status']?.toString(),
    );
  }
}

class MusicUserDataState {
  final bool isListened;
  final bool isFavorite;
  final int? rating;
  final DateTime? listenedAt;
  final DateTime? ratedAt;
  final String? libraryStatus;

  const MusicUserDataState({
    required this.isListened,
    required this.isFavorite,
    required this.rating,
    this.listenedAt,
    this.ratedAt,
    this.libraryStatus,
  });

  const MusicUserDataState.empty()
      : isListened = false,
        isFavorite = false,
        rating = null,
        listenedAt = null,
        ratedAt = null,
        libraryStatus = null;

  int? get ratingStars {
    final value = rating;
    if (value == null) {
      return null;
    }

    return (value / 2).round().clamp(1, 5).toInt();
  }

  MusicUserDataState copyWith({
    bool? isListened,
    bool? isFavorite,
    Object? rating = _unset,
    Object? listenedAt = _unset,
    Object? ratedAt = _unset,
    Object? libraryStatus = _unset,
  }) {
    return MusicUserDataState(
      isListened: isListened ?? this.isListened,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: identical(rating, _unset) ? this.rating : rating as int?,
      listenedAt: identical(listenedAt, _unset)
          ? this.listenedAt
          : listenedAt as DateTime?,
      ratedAt: identical(ratedAt, _unset) ? this.ratedAt : ratedAt as DateTime?,
      libraryStatus: identical(libraryStatus, _unset)
          ? this.libraryStatus
          : libraryStatus as String?,
    );
  }
}

const Object _unset = Object();

class MusicUserDataService extends ChangeNotifier {
  MusicUserDataService._();

  static final MusicUserDataService instance = MusicUserDataService._();

  SupabaseClient get client => Supabase.instance.client;

  final Map<String, MusicUserDataState> _cache = {};
  final Map<String, Map<String, dynamic>> _allRows = {};

  // Changes whenever the visible account state is reset/reloaded. Async music
  // requests capture this value so a response from an old account can never
  // repopulate the cache after logout/account switching.
  int _stateGeneration = 0;

  String _key(String entityType, String entityId) => '$entityType:$entityId';

  bool _sessionStillCurrent(int generation, String userId) {
    return generation == _stateGeneration &&
        client.auth.currentUser?.id == userId;
  }

  List<MusicLibraryEntry> get allEntries => _allRows.values
      .map((row) => MusicLibraryEntry.fromRow(row))
      .where((entry) => entry.entityId.isNotEmpty)
      .toList(growable: false);

  List<MusicLibraryEntry> get albumEntries =>
      allEntries.where((entry) => entry.isAlbum).toList(growable: false);

  List<MusicLibraryEntry> get trackEntries =>
      allEntries.where((entry) => entry.isTrack).toList(growable: false);

  int get listenedAlbumCount =>
      albumEntries.where((entry) => entry.isListened).length;

  int get listenedTrackCount =>
      trackEntries.where((entry) => entry.isListened).length;

  int get albumRatingCount =>
      albumEntries.where((entry) => entry.rating != null).length;

  int get trackRatingCount =>
      trackEntries.where((entry) => entry.rating != null).length;

  int get listenedAlbumRuntimeMinutes {
    final totalMs = albumEntries
        .where((entry) => entry.isListened)
        .fold<int>(0, (sum, entry) => sum + entry.durationMs);
    return (totalMs / 60000).round();
  }

  int get listenedTrackRuntimeMinutes {
    final totalMs = trackEntries
        .where((entry) => entry.isListened)
        .fold<int>(0, (sum, entry) => sum + entry.durationMs);
    return (totalMs / 60000).round();
  }

  String _canonicalMusicGenre(List<String> genres) {
    final normalized = genres
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    bool hasAny(List<String> needles) {
      return normalized.any(
        (genre) => needles.any((needle) => genre.contains(needle)),
      );
    }

    if (hasAny(['metal'])) return 'Metal';
    if (hasAny(['punk'])) return 'Punk';
    if (hasAny(['hip hop', 'hip-hop', 'rap'])) return 'Hip-Hop';
    if (hasAny(['electronic', 'techno', 'house', 'trance', 'edm', 'dance'])) {
      return 'Electronic';
    }
    if (hasAny(['jazz'])) return 'Jazz';
    if (hasAny(['classical', 'orchestral', 'baroque', 'romantic era'])) {
      return 'Classical';
    }
    if (hasAny(['country', 'americana'])) return 'Country Music';
    if (hasAny(['blues'])) return 'Blues';
    if (hasAny(['r&b', 'rhythm and blues', 'soul', 'neo soul'])) return 'R&B / Soul';
    if (hasAny(['folk', 'singer-songwriter'])) return 'Folk';
    if (hasAny(['reggae', 'ska', 'dub'])) return 'Reggae';
    if (hasAny(['funk'])) return 'Funk';
    if (hasAny(['latin', 'salsa', 'bachata', 'reggaeton', 'bossa nova'])) {
      return 'Latin';
    }
    if (hasAny(['rock', 'grunge', 'alternative', 'shoegaze', 'indie rock'])) {
      return 'Rock';
    }
    if (hasAny(['pop', 'indie pop', 'synthpop'])) return 'Pop';
    if (hasAny(['world', 'afrobeat', 'afrobeats', 'k-pop', 'j-pop'])) {
      return 'World Music';
    }

    return 'Other';
  }

  Map<String, int> get listenedGenreRuntimeMinutes {
    final totalsMs = <String, int>{};

    for (final entry in trackEntries.where((entry) => entry.isListened)) {
      final genre = _canonicalMusicGenre(entry.genres);
      final duration = entry.durationMs > 0 ? entry.durationMs : 0;
      totalsMs[genre] = (totalsMs[genre] ?? 0) + duration;
    }

    final result = <String, int>{};
    for (final entry in totalsMs.entries) {
      result[entry.key] = (entry.value / 60000).round();
    }

    return result;
  }

  Map<String, int> get listenedGenreTrackCounts {
    final counts = <String, int>{};

    for (final entry in trackEntries.where((entry) => entry.isListened)) {
      final genre = _canonicalMusicGenre(entry.genres);
      counts[genre] = (counts[genre] ?? 0) + 1;
    }

    return counts;
  }

  String? get dominantGenre {
    final runtime = listenedGenreRuntimeMinutes;
    final trackCounts = listenedGenreTrackCounts;

    if (runtime.isEmpty) return null;

    final entries = runtime.entries.toList()
      ..sort((a, b) {
        final runtimeCompare = b.value.compareTo(a.value);
        if (runtimeCompare != 0) return runtimeCompare;
        return (trackCounts[b.key] ?? 0).compareTo(trackCounts[a.key] ?? 0);
      });

    final winner = entries.first.key;
    return winner == 'Other' ? null : winner;
  }

  String? get musicTitleSuffix {
    switch (dominantGenre) {
      case 'Metal':
        return 'METALHEAD';
      case 'Punk':
        return 'PUNK';
      case 'Hip-Hop':
        return 'BEATHEAD';
      case 'Electronic':
        return 'RAVER';
      case 'Jazz':
        return 'JAZZ CAT';
      case 'Classical':
        return 'VIRTUOSO';
      case 'Country Music':
        return 'OUTLAW';
      case 'Blues':
        return 'BLUES SOUL';
      case 'R&B / Soul':
        return 'GROOVER';
      case 'Folk':
        return 'TROUBADOUR';
      case 'Reggae':
        return 'REGGAE SOUL';
      case 'Funk':
        return 'FUNKSTER';
      case 'Rock':
        return 'ROCKER';
      case 'Pop':
        return 'POPSTER';
      case 'Latin':
        return 'RHYTHM RIDER';
      case 'World Music':
        return 'WORLD LISTENER';
      default:
        return null;
    }
  }

  Future<void> loadAll() async {
    final generation = ++_stateGeneration;
    final user = client.auth.currentUser;

    // Clear synchronously so a newly signed-in account never sees the previous
    // account's music state while its own rows are downloading.
    _cache.clear();
    _allRows.clear();
    notifyListeners();

    if (user == null) {
      return;
    }

    final userId = user.id;
    final rows = await client
        .from('music_user_data')
        .select()
        .eq('user_id', userId);

    if (!_sessionStillCurrent(generation, userId)) {
      return;
    }

    for (final raw in rows) {
      _rememberRow(Map<String, dynamic>.from(raw));
    }

    notifyListeners();
  }

  MusicUserDataState albumState(String albumId) {
    return _cache[_key('album', albumId)] ?? const MusicUserDataState.empty();
  }

  MusicUserDataState trackState(String trackId) {
    return _cache[_key('track', trackId)] ?? const MusicUserDataState.empty();
  }

  Future<void> loadAlbum(MusicAlbum album, List<MusicTrack> tracks) async {
    final user = client.auth.currentUser;
    final generation = _stateGeneration;

    if (user == null) {
      _clearAlbumCache(album.id, tracks);
      notifyListeners();
      return;
    }

    final Future<dynamic> albumFuture = client
        .from('music_user_data')
        .select()
        .eq('user_id', user.id)
        .eq('entity_type', 'album')
        .eq('entity_id', album.id)
        .maybeSingle();

    final trackIds = tracks.map((track) => track.id).toSet().toList();

    late final Future<dynamic> trackFuture;
    if (trackIds.isEmpty) {
      trackFuture = Future<dynamic>.value(const <dynamic>[]);
    } else {
      trackFuture = client
          .from('music_user_data')
          .select()
          .eq('user_id', user.id)
          .eq('entity_type', 'track')
          .inFilter('entity_id', trackIds);
    }

    final results = await Future.wait<dynamic>([albumFuture, trackFuture]);

    if (!_sessionStillCurrent(generation, user.id)) {
      return;
    }

    final rawAlbum = results[0];
    final rawTracks = List<dynamic>.from(results[1] as List? ?? const []);

    if (rawAlbum is Map) {
      final row = Map<String, dynamic>.from(rawAlbum);
      _cache[_key('album', album.id)] = _stateFromRow(row);
      _rememberRow(row);
    } else {
      _cache[_key('album', album.id)] = const MusicUserDataState.empty();
      _allRows.remove(_key('album', album.id));
    }

    // Reset every requested track before applying the server response. This
    // also removes stale rows if a track was deleted/cleared on another device.
    for (final track in tracks) {
      _cache[_key('track', track.id)] = const MusicUserDataState.empty();
      _allRows.remove(_key('track', track.id));
    }

    for (final raw in rawTracks) {
      if (raw is! Map) {
        continue;
      }

      final row = Map<String, dynamic>.from(raw);
      final id = row['entity_id']?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }

      _cache[_key('track', id)] = _stateFromRow(row);
      _rememberRow(row);
    }

    // Track state is the source of truth for album completion. This repairs
    // any stale album flag and also handles an album becoming complete after
    // its final individual song was listened to.
    if (tracks.isNotEmpty) {
      final allListened =
          tracks.every((track) => trackState(track.id).isListened);
      final anyListened =
          tracks.any((track) => trackState(track.id).isListened);
      final currentAlbum = albumState(album.id);
      final reconciledStatus =
          anyListened ? null : currentAlbum.libraryStatus;

      if (currentAlbum.isListened != allListened ||
          currentAlbum.libraryStatus != reconciledStatus) {
        final now = DateTime.now().toUtc();
        final reconciled = currentAlbum.copyWith(
          isListened: allListened,
          listenedAt: allListened ? (currentAlbum.listenedAt ?? now) : null,
          rating: allListened ? currentAlbum.rating : null,
          ratedAt: allListened ? currentAlbum.ratedAt : null,
          libraryStatus: reconciledStatus,
        );

        await _upsertAlbum(
          album,
          tracks,
          reconciled,
          expectedGeneration: generation,
          expectedUserId: user.id,
        );

        if (!_sessionStillCurrent(generation, user.id)) {
          return;
        }

        _cache[_key('album', album.id)] = reconciled;
      }
    }

    notifyListeners();
  }

  Future<void> setAlbumListened({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
    required bool listened,
  }) async {
    final user = _requireUser();
    final generation = _stateGeneration;

    final now = DateTime.now().toUtc();
    final albumCurrent = albumState(album.id);
    final albumNext = albumCurrent.copyWith(
      isListened: listened,
      listenedAt: listened ? (albumCurrent.listenedAt ?? now) : null,
      rating: listened ? albumCurrent.rating : null,
      ratedAt: listened ? albumCurrent.ratedAt : null,
      libraryStatus: listened ? null : albumCurrent.libraryStatus,
    );

    final rows = <Map<String, dynamic>>[
      _albumRow(album, tracks, albumNext),
    ];

    final nextTrackStates = <String, MusicUserDataState>{};

    final seenTrackIds = <String>{};

    for (final track in tracks) {
      final current = trackState(track.id);
      final next = current.copyWith(
        isListened: listened,
        listenedAt: listened ? (current.listenedAt ?? now) : null,
      );

      if (seenTrackIds.add(track.id)) {
        rows.add(_trackRow(album, track, next));
      }
      nextTrackStates[track.id] = next;
    }

    await client.from('music_user_data').upsert(
      rows,
      onConflict: 'user_id,entity_type,entity_id',
    );

    if (!_sessionStillCurrent(generation, user.id)) {
      return;
    }

    for (final row in rows) {
      _rememberRow(row);
    }

    _cache[_key('album', album.id)] = albumNext;
    for (final entry in nextTrackStates.entries) {
      _cache[_key('track', entry.key)] = entry.value;
    }

    notifyListeners();
  }

  Future<void> setTrackListened({
    required MusicAlbum album,
    required List<MusicTrack> allTracks,
    required MusicTrack track,
    required bool listened,
  }) async {
    final user = _requireUser();
    final generation = _stateGeneration;

    final now = DateTime.now().toUtc();
    final currentTrack = trackState(track.id);
    final nextTrack = currentTrack.copyWith(
      isListened: listened,
      listenedAt: listened ? (currentTrack.listenedAt ?? now) : null,
    );

    // Update the local value before computing whether every song is listened.
    _cache[_key('track', track.id)] = nextTrack;

    final allListened = allTracks.isNotEmpty &&
        allTracks.every((item) => trackState(item.id).isListened);

    final currentAlbum = albumState(album.id);
    final nextAlbum = currentAlbum.copyWith(
      isListened: allListened,
      listenedAt: allListened ? (currentAlbum.listenedAt ?? now) : null,
      rating: allListened ? currentAlbum.rating : null,
      ratedAt: allListened ? currentAlbum.ratedAt : null,
      // Starting or resuming any song removes the album from Plan/Dropped.
      libraryStatus: listened ? null : currentAlbum.libraryStatus,
    );

    final rows = [
      _trackRow(album, track, nextTrack),
      _albumRow(album, allTracks, nextAlbum),
    ];

    try {
      await client.from('music_user_data').upsert(
        rows,
        onConflict: 'user_id,entity_type,entity_id',
      );
    } catch (_) {
      // Restore the previous local state if the database write failed.
      if (_sessionStillCurrent(generation, user.id)) {
        _cache[_key('track', track.id)] = currentTrack;
      }
      rethrow;
    }

    if (!_sessionStillCurrent(generation, user.id)) {
      return;
    }

    for (final row in rows) {
      _rememberRow(row);
    }

    _cache[_key('album', album.id)] = nextAlbum;
    notifyListeners();
  }

  Future<void> setAlbumLibraryStatus({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
    required String? status,
  }) async {
    final user = _requireUser();
    final generation = _stateGeneration;

    if (status != null && status != 'plan' && status != 'dropped') {
      throw ArgumentError.value(
        status,
        'status',
        'Unsupported album library status.',
      );
    }

    final current = albumState(album.id);

    if (current.isListened && status != null) {
      throw StateError(
        'A listened album cannot be moved to Plan or Dropped.',
      );
    }

    final next = current.copyWith(libraryStatus: status);

    await _upsertAlbum(
      album,
      tracks,
      next,
      expectedGeneration: generation,
      expectedUserId: user.id,
    );

    if (!_sessionStillCurrent(generation, user.id)) {
      return;
    }

    _cache[_key('album', album.id)] = next;
    notifyListeners();
  }

  Future<void> toggleAlbumFavorite({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
  }) async {
    final user = _requireUser();
    final generation = _stateGeneration;

    final current = albumState(album.id);
    final next = current.copyWith(isFavorite: !current.isFavorite);

    await _upsertAlbum(
      album,
      tracks,
      next,
      expectedGeneration: generation,
      expectedUserId: user.id,
    );

    if (!_sessionStillCurrent(generation, user.id)) {
      return;
    }

    _cache[_key('album', album.id)] = next;
    notifyListeners();
  }

  Future<void> toggleTrackFavorite({
    required MusicAlbum album,
    required MusicTrack track,
  }) async {
    final user = _requireUser();
    final generation = _stateGeneration;

    final current = trackState(track.id);
    final next = current.copyWith(isFavorite: !current.isFavorite);

    await _upsertTrack(
      album,
      track,
      next,
      expectedGeneration: generation,
      expectedUserId: user.id,
    );

    if (!_sessionStillCurrent(generation, user.id)) {
      return;
    }

    _cache[_key('track', track.id)] = next;
    notifyListeners();
  }

  Future<void> setAlbumRating({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
    required int? stars,
  }) async {
    final user = _requireUser();
    final generation = _stateGeneration;

    if (stars != null && (stars < 1 || stars > 5)) {
      throw ArgumentError.value(stars, 'stars', 'Rating must be 1–5.');
    }

    final current = albumState(album.id);

    if (stars != null && !current.isListened) {
      throw StateError('Listen to the full album before rating it.');
    }

    final now = DateTime.now().toUtc();
    final next = current.copyWith(
      rating: stars == null ? null : stars * 2,
      ratedAt: stars == null ? null : now,
    );

    await _upsertAlbum(
      album,
      tracks,
      next,
      expectedGeneration: generation,
      expectedUserId: user.id,
    );

    if (!_sessionStillCurrent(generation, user.id)) {
      return;
    }

    _cache[_key('album', album.id)] = next;
    notifyListeners();
  }

  Future<void> setTrackRating({
    required MusicAlbum album,
    required MusicTrack track,
    required int? stars,
  }) async {
    final user = _requireUser();
    final generation = _stateGeneration;

    if (stars != null && (stars < 1 || stars > 5)) {
      throw ArgumentError.value(stars, 'stars', 'Rating must be 1–5.');
    }

    final current = trackState(track.id);
    final now = DateTime.now().toUtc();
    final next = current.copyWith(
      rating: stars == null ? null : stars * 2,
      ratedAt: stars == null ? null : now,
    );

    await _upsertTrack(
      album,
      track,
      next,
      expectedGeneration: generation,
      expectedUserId: user.id,
    );

    if (!_sessionStillCurrent(generation, user.id)) {
      return;
    }

    _cache[_key('track', track.id)] = next;
    notifyListeners();
  }

  Future<void> _upsertAlbum(
    MusicAlbum album,
    List<MusicTrack> tracks,
    MusicUserDataState state, {
    int? expectedGeneration,
    String? expectedUserId,
  }) async {
    final row = _albumRow(album, tracks, state);
    await client.from('music_user_data').upsert(
      row,
      onConflict: 'user_id,entity_type,entity_id',
    );

    if (expectedGeneration != null && expectedUserId != null &&
        !_sessionStillCurrent(expectedGeneration, expectedUserId)) {
      return;
    }

    _rememberRow(row);
  }

  Future<void> _upsertTrack(
    MusicAlbum album,
    MusicTrack track,
    MusicUserDataState state, {
    int? expectedGeneration,
    String? expectedUserId,
  }) async {
    final row = _trackRow(album, track, state);
    await client.from('music_user_data').upsert(
      row,
      onConflict: 'user_id,entity_type,entity_id',
    );

    if (expectedGeneration != null && expectedUserId != null &&
        !_sessionStillCurrent(expectedGeneration, expectedUserId)) {
      return;
    }

    _rememberRow(row);
  }

  Map<String, dynamic> _albumRow(
    MusicAlbum album,
    List<MusicTrack> tracks,
    MusicUserDataState state,
  ) {
    final user = _requireUser();
    int runtimeMs = 0;
    for (final track in tracks) {
      final duration = track.durationMs;
      if (duration != null && duration > 0) {
        runtimeMs += duration;
      }
    }

    return {
      'user_id': user.id,
      'entity_type': 'album',
      'entity_id': album.id,
      'artist_id': album.artistId,
      'artist_name': album.artistName,
      'album_id': album.id,
      'album_title': album.title,
      'title': album.title,
      'release_year': album.year,
      'cover_url': album.coverUrl,
      'genre_names': album.genres,
      'duration_ms': runtimeMs,
      'track_number': null,
      'disc_number': null,
      'is_listened': state.isListened,
      'is_favorite': state.isFavorite,
      'rating': state.rating,
      'library_status': state.libraryStatus,
      'listened_at': state.listenedAt?.toIso8601String(),
      'rated_at': state.ratedAt?.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _trackRow(
    MusicAlbum album,
    MusicTrack track,
    MusicUserDataState state,
  ) {
    final user = _requireUser();

    return {
      'user_id': user.id,
      'entity_type': 'track',
      'entity_id': track.id,
      'artist_id': album.artistId,
      'artist_name': album.artistName,
      'album_id': album.id,
      'album_title': album.title,
      'title': track.title,
      'release_year': album.year,
      'cover_url': album.coverUrl,
      'genre_names': album.genres,
      'duration_ms': track.durationMs ?? 0,
      'track_number': track.number,
      'disc_number': track.discNumber,
      'is_listened': state.isListened,
      'is_favorite': state.isFavorite,
      'rating': state.rating,
      'library_status': null,
      'listened_at': state.listenedAt?.toIso8601String(),
      'rated_at': state.ratedAt?.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  void _rememberRow(Map<String, dynamic> row) {
    final entityType = row['entity_type']?.toString() ?? '';
    final entityId = row['entity_id']?.toString() ?? '';
    if (entityType.isEmpty || entityId.isEmpty) return;

    _allRows[_key(entityType, entityId)] = Map<String, dynamic>.from(row);
  }

  MusicUserDataState _stateFromRow(Map<String, dynamic> row) {
    DateTime? date(dynamic value) {
      final text = value?.toString();
      return text == null || text.isEmpty ? null : DateTime.tryParse(text);
    }

    final rawRating = row['rating'];

    return MusicUserDataState(
      isListened: row['is_listened'] == true,
      isFavorite: row['is_favorite'] == true,
      rating: rawRating is num ? rawRating.toInt() : null,
      listenedAt: date(row['listened_at']),
      ratedAt: date(row['rated_at']),
      libraryStatus: row['library_status']?.toString(),
    );
  }

  User _requireUser() {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in.');
    }
    return user;
  }

  void _clearAlbumCache(String albumId, List<MusicTrack> tracks) {
    _cache.remove(_key('album', albumId));
    _allRows.remove(_key('album', albumId));
    for (final track in tracks) {
      _cache.remove(_key('track', track.id));
      _allRows.remove(_key('track', track.id));
    }
  }

  void clearCache() {
    _stateGeneration++;
    _cache.clear();
    _allRows.clear();
    notifyListeners();
  }
}
