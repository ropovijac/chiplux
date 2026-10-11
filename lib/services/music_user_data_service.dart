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

  String _key(String entityType, String entityId) => '$entityType:$entityId';

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

  String? get dominantGenre {
    final weighted = <String, int>{};

    for (final entry in trackEntries.where((entry) => entry.isListened)) {
      final weight = entry.durationMs > 0 ? entry.durationMs : 1;
      for (final genre in entry.genres.toSet()) {
        final clean = genre.trim();
        if (clean.isEmpty) continue;
        weighted[clean] = (weighted[clean] ?? 0) + weight;
      }
    }

    if (weighted.isEmpty) return null;
    return weighted.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String? get musicTitleSuffix {
    final genre = dominantGenre?.toLowerCase();
    if (genre == null || genre.isEmpty) return null;

    if (genre.contains('metal')) return 'METALHEAD';
    if (genre.contains('punk')) return 'PUNK';
    if (genre.contains('hip hop') ||
        genre.contains('hip-hop') ||
        genre == 'rap' ||
        genre.contains(' rap')) {
      return 'BEATHEAD';
    }
    if (genre.contains('electronic') ||
        genre.contains('techno') ||
        genre.contains('house') ||
        genre.contains('trance') ||
        genre.contains('dance')) {
      return 'RAVER';
    }
    if (genre.contains('jazz')) return 'JAZZ CAT';
    if (genre.contains('classical') || genre.contains('orchestral')) {
      return 'VIRTUOSO';
    }
    if (genre.contains('country')) return 'OUTLAW';
    if (genre.contains('blues')) return 'BLUES SOUL';
    if (genre.contains('r&b') ||
        genre.contains('rhythm and blues') ||
        genre == 'soul') {
      return 'GROOVER';
    }
    if (genre.contains('folk')) return 'TROUBADOUR';
    if (genre.contains('reggae')) return 'REGGAE SOUL';
    if (genre.contains('funk')) return 'FUNKSTER';
    if (genre.contains('rock') ||
        genre.contains('grunge') ||
        genre.contains('alternative')) {
      return 'ROCKER';
    }
    if (genre.contains('pop')) return 'POPSTER';
    return 'MUSIC LOVER';
  }

  Future<void> loadAll() async {
    final user = client.auth.currentUser;
    _allRows.clear();

    if (user == null) {
      notifyListeners();
      return;
    }

    final rows = await client
        .from('music_user_data')
        .select()
        .eq('user_id', user.id);

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
    final rawAlbum = results[0];
    final rawTracks = List<dynamic>.from(results[1] as List? ?? const []);

    if (rawAlbum is Map) {
      final row = Map<String, dynamic>.from(rawAlbum);
      _cache[_key('album', album.id)] = _stateFromRow(row);
      _rememberRow(row);
    } else {
      _cache[_key('album', album.id)] = const MusicUserDataState.empty();
    }

    for (final track in tracks) {
      _cache[_key('track', track.id)] = const MusicUserDataState.empty();
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
        );
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
    _requireUser();

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
    _requireUser();

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
      _cache[_key('track', track.id)] = currentTrack;
      rethrow;
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
    _requireUser();

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

    await _upsertAlbum(album, tracks, next);
    _cache[_key('album', album.id)] = next;
    notifyListeners();
  }

  Future<void> toggleAlbumFavorite({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
  }) async {
    _requireUser();

    final current = albumState(album.id);
    final next = current.copyWith(isFavorite: !current.isFavorite);

    await _upsertAlbum(album, tracks, next);
    _cache[_key('album', album.id)] = next;
    notifyListeners();
  }

  Future<void> toggleTrackFavorite({
    required MusicAlbum album,
    required MusicTrack track,
  }) async {
    _requireUser();

    final current = trackState(track.id);
    final next = current.copyWith(isFavorite: !current.isFavorite);

    await _upsertTrack(album, track, next);
    _cache[_key('track', track.id)] = next;
    notifyListeners();
  }

  Future<void> setAlbumRating({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
    required int? stars,
  }) async {
    _requireUser();

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

    await _upsertAlbum(album, tracks, next);
    _cache[_key('album', album.id)] = next;
    notifyListeners();
  }

  Future<void> setTrackRating({
    required MusicAlbum album,
    required MusicTrack track,
    required int? stars,
  }) async {
    _requireUser();

    if (stars != null && (stars < 1 || stars > 5)) {
      throw ArgumentError.value(stars, 'stars', 'Rating must be 1–5.');
    }

    final current = trackState(track.id);
    final now = DateTime.now().toUtc();
    final next = current.copyWith(
      rating: stars == null ? null : stars * 2,
      ratedAt: stars == null ? null : now,
    );

    await _upsertTrack(album, track, next);
    _cache[_key('track', track.id)] = next;
    notifyListeners();
  }

  Future<void> _upsertAlbum(
    MusicAlbum album,
    List<MusicTrack> tracks,
    MusicUserDataState state,
  ) async {
    final row = _albumRow(album, tracks, state);
    await client.from('music_user_data').upsert(
      row,
      onConflict: 'user_id,entity_type,entity_id',
    );
    _rememberRow(row);
  }

  Future<void> _upsertTrack(
    MusicAlbum album,
    MusicTrack track,
    MusicUserDataState state,
  ) async {
    final row = _trackRow(album, track, state);
    await client.from('music_user_data').upsert(
      row,
      onConflict: 'user_id,entity_type,entity_id',
    );
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
    for (final track in tracks) {
      _cache.remove(_key('track', track.id));
    }
  }

  void clearCache() {
    _cache.clear();
    _allRows.clear();
    notifyListeners();
  }
}
