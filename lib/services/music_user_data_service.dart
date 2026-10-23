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

  // Account and request revisions prevent slow network reads from replacing
  // newly saved music state, or data from a previous signed-in user.
  int _stateGeneration = 0;
  String? _cachedUserId;
  int _requestSequence = 0;
  final Map<String, int> _lastAppliedRequest = {};
  int _saveSequence = 0;
  final Map<String, int> _lastSavedRevision = {};
  Future<void>? _pendingLoadAll;
  String? _pendingLoadUserId;

  // Serialize mutations so two rapid taps cannot both write a snapshot of
  // the same old album/track state and cause a lost update.
  Future<void> _pendingSave = Future<void>.value();

  Future<void> _serializeSave(Future<void> Function() action) {
    final result = _pendingSave.then((_) => action());
    _pendingSave = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _rememberCommittedRow(Map<String, dynamic> row) {
    final key = _key(row['entity_type']?.toString() ?? '',
        row['entity_id']?.toString() ?? '');
    _lastSavedRevision[key] = ++_saveSequence;
    _lastAppliedRequest[key] = ++_requestSequence;
    _rememberRow(row);
  }

  bool _canApplyRead(String key, int request, int saveRevision) =>
      (_lastSavedRevision[key] ?? 0) <= saveRevision &&
      (_lastAppliedRequest[key] ?? 0) <= request;

  void _acceptReadRow(Map<String, dynamic> row, int request, int saveRevision) {
    final entityType = row['entity_type']?.toString() ?? '';
    final entityId = row['entity_id']?.toString() ?? '';
    if (entityType.isEmpty || entityId.isEmpty) return;
    final key = _key(entityType, entityId);
    if (!_canApplyRead(key, request, saveRevision)) return;
    _lastAppliedRequest[key] = request;
    _rememberRow(row);
  }

  void _removeMissingReadRow(String key, int request, int saveRevision) {
    if (!_canApplyRead(key, request, saveRevision)) return;
    _lastAppliedRequest[key] = request;
    _cache.remove(key);
    _allRows.remove(key);
  }

  void _prepareAccount(String? userId) {
    if (_cachedUserId == userId) return;
    _cachedUserId = userId;
    _stateGeneration++;
    _cache.clear();
    _allRows.clear();
    _lastAppliedRequest.clear();
    _lastSavedRevision.clear();
    _pendingLoadAll = null;
    _pendingLoadUserId = null;
    notifyListeners();
  }

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

  Future<void> loadAll() {
    final user = client.auth.currentUser;
    _prepareAccount(user?.id);
    if (user == null) return Future<void>.value();

    // Profile and Library can request this simultaneously. Share the same
    // read, and do not clear visible ratings while the request is pending.
    final pending = _pendingLoadAll;
    if (pending != null && _pendingLoadUserId == user.id) return pending;

    final generation = _stateGeneration;
    final userId = user.id;
    final request = ++_requestSequence;
    final saveRevision = _saveSequence;

    Future<void> fetch() async {
      // Supabase's Data API can cap a SELECT at 1,000 rows. A music library
      // with more than that many tracks must be paged, or later ratings appear
      // missing after sign-in despite still existing in the database.
      const pageSize = 500;
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += pageSize) {
        final page = await client.from('music_user_data').select()
            .eq('user_id', userId)
            .order('entity_type')
            .order('entity_id')
            .range(offset, offset + pageSize - 1);
        if (!_sessionStillCurrent(generation, userId)) return;
        rows.addAll(page.map((row) => Map<String, dynamic>.from(row)));
        if (page.length < pageSize) break;
      }

      final received = <String>{};
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final key = _key(row['entity_type']?.toString() ?? '',
            row['entity_id']?.toString() ?? '');
        received.add(key);
        _acceptReadRow(row, request, saveRevision);
      }
      for (final key in <String>{..._allRows.keys, ..._cache.keys}) {
        if (!received.contains(key)) {
          _removeMissingReadRow(key, request, saveRevision);
        }
      }
      notifyListeners();
    }

    late final Future<void> task;
    task = fetch().whenComplete(() {
      if (identical(_pendingLoadAll, task)) {
        _pendingLoadAll = null;
        _pendingLoadUserId = null;
      }
    });
    _pendingLoadAll = task;
    _pendingLoadUserId = userId;
    return task;
  }

  MusicUserDataState albumState(String albumId) {
    return _cache[_key('album', albumId)] ?? const MusicUserDataState.empty();
  }

  MusicUserDataState trackState(String trackId) {
    return _cache[_key('track', trackId)] ?? const MusicUserDataState.empty();
  }

  Future<void> loadAlbum(MusicAlbum album, List<MusicTrack> tracks) async {
    final user = client.auth.currentUser;
    _prepareAccount(user?.id);
    final generation = _stateGeneration;
    final request = ++_requestSequence;
    final saveRevision = _saveSequence;

    if (user == null) {
      _clearAlbumCache(album.id, tracks);
      notifyListeners();
      return;
    }

    final albumFuture = client
        .from('music_user_data')
        .select()
        .eq('user_id', user.id)
        .eq('entity_type', 'album')
        .eq('entity_id', album.id)
        .maybeSingle();

    final trackIds = tracks.map((track) => track.id).toSet().toList();
    final Future<List<dynamic>> trackFuture = trackIds.isEmpty
        ? Future<List<dynamic>>.value(<dynamic>[])
        : client.from('music_user_data').select()
            .eq('user_id', user.id)
            .eq('entity_type', 'track')
            .inFilter('entity_id', trackIds).then((rows) => List<dynamic>.from(rows));

    final results = await Future.wait<dynamic>([albumFuture, trackFuture]);
    if (!_sessionStillCurrent(generation, user.id)) return;

    final rawAlbum = results[0];
    final albumKey = _key('album', album.id);
    if (rawAlbum is Map) {
      _acceptReadRow(Map<String, dynamic>.from(rawAlbum), request, saveRevision);
    } else {
      _removeMissingReadRow(albumKey, request, saveRevision);
    }

    final receivedTrackIds = <String>{};
    for (final raw in List<dynamic>.from(results[1] as List? ?? const [])) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final id = row['entity_id']?.toString();
      if (id == null || id.isEmpty) continue;
      receivedTrackIds.add(id);
      _acceptReadRow(row, request, saveRevision);
    }
    for (final id in trackIds) {
      if (!receivedTrackIds.contains(id)) {
        _removeMissingReadRow(_key('track', id), request, saveRevision);
      }
    }

    // Keep album completion read-only. Reconcile ONLY its derived rating,
    // after the full remote track-rating set is available.
    notifyListeners();
    await reconcileAlbumRating(album, tracks,
        expectedUserId: user.id, expectedGeneration: generation);
  }

  Future<void> setAlbumListened({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
    required bool listened,
  }) => _serializeSave(() async {
    final user = _requireUser();
    final generation = _stateGeneration;

    final now = DateTime.now().toUtc();
    final albumCurrent = albumState(album.id);
    final albumNext = _derivedAlbumRating(albumCurrent.copyWith(
      isListened: listened,
      listenedAt: listened ? (albumCurrent.listenedAt ?? now) : null,
      libraryStatus: listened ? null : albumCurrent.libraryStatus,
    ), tracks);

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
      _rememberCommittedRow(row);
    }

    _cache[_key('album', album.id)] = albumNext;
    for (final entry in nextTrackStates.entries) {
      _cache[_key('track', entry.key)] = entry.value;
    }

    notifyListeners();
  });

  Future<void> setTrackListened({
    required MusicAlbum album,
    required List<MusicTrack> allTracks,
    required MusicTrack track,
    required bool listened,
  }) => _serializeSave(() async {
    final user = _requireUser();
    final generation = _stateGeneration;

    final now = DateTime.now().toUtc();
    final currentTrack = trackState(track.id);
    final nextTrack = currentTrack.copyWith(
      isListened: listened,
      listenedAt: listened ? (currentTrack.listenedAt ?? now) : null,
    );

    // Derive completion from the proposed track value, without mutating the
    // visible cache until the database confirms the save.
    final allListened = allTracks.isNotEmpty &&
        allTracks.every((item) => item.id == track.id
            ? nextTrack.isListened : trackState(item.id).isListened);

    final currentAlbum = albumState(album.id);
    final nextAlbum = _derivedAlbumRating(currentAlbum.copyWith(
      isListened: allListened,
      listenedAt: allListened ? (currentAlbum.listenedAt ?? now) : null,
      // Starting or resuming any song removes the album from Plan/Dropped.
      libraryStatus: listened ? null : currentAlbum.libraryStatus,
    ), allTracks, changedTrackId: track.id, changedState: nextTrack);

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
      _rememberCommittedRow(row);
    }

    _cache[_key('album', album.id)] = nextAlbum;
    notifyListeners();
  });

  Future<void> setAlbumLibraryStatus({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
    required String? status,
  }) => _serializeSave(() async {
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
  });

  Future<void> toggleAlbumFavorite({
    required MusicAlbum album,
    required List<MusicTrack> tracks,
  }) => _serializeSave(() async {
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
  });

  Future<void> toggleTrackFavorite({
    required MusicAlbum album,
    required List<MusicTrack> allTracks,
    required MusicTrack track,
  }) => _serializeSave(() async {
    final user = _requireUser();
    final generation = _stateGeneration;
    final current = trackState(track.id);
    final favoriting = !current.isFavorite;
    final autoListen = favoriting && !current.isListened;
    final now = DateTime.now().toUtc();
    final next = current.copyWith(
      isFavorite: favoriting,
      isListened: autoListen ? true : current.isListened,
      listenedAt: autoListen ? (current.listenedAt ?? now) : current.listenedAt,
    );

    await _persistTrackInteraction(
      album: album,
      allTracks: allTracks,
      track: track,
      next: next,
      autoListen: autoListen,
      expectedGeneration: generation,
      expectedUserId: user.id,
    );
  });

  // Exact 5-star album average; unavailable until every track is rated.
  double? albumAverageStars(List<MusicTrack> tracks, {String? changedTrackId,
      MusicUserDataState? changedState}) {
    if (tracks.isEmpty) return null;
    var total = 0;
    final ids = <String>{};
    for (final track in tracks) {
      if (!ids.add(track.id)) continue;
      final state = track.id == changedTrackId && changedState != null
          ? changedState : trackState(track.id);
      if (state.rating == null) return null;
      total += state.rating!;
    }
    if (ids.isEmpty) return null;
    return total / (2.0 * ids.length);
  }

  MusicUserDataState _derivedAlbumRating(MusicUserDataState current,
      List<MusicTrack> tracks, {String? changedTrackId,
      MusicUserDataState? changedState}) {
    // The existing server constraint requires a rated album to be listened.
    final average = current.isListened
        ? albumAverageStars(tracks,
            changedTrackId: changedTrackId, changedState: changedState)
        : null;
    final now = DateTime.now().toUtc();
    return current.copyWith(
      rating: average == null ? null : (average * 2).round().clamp(1, 10).toInt(),
      ratedAt: average == null ? null : (current.ratedAt ?? now),
    );
  }

  // Reconcile legacy manually rated albums after ALL track rows have loaded.
  // Do not base this calculation on an incomplete album-detail request.
  Future<void> reconcileAlbumRating(MusicAlbum album,
      List<MusicTrack> tracks, {String? expectedUserId,
      int? expectedGeneration}) => _serializeSave(() async {
    final user = client.auth.currentUser;
    if (user == null ||
        (expectedUserId != null && user.id != expectedUserId) ||
        (expectedGeneration != null && expectedGeneration != _stateGeneration)) {
      return;
    }
    final generation = _stateGeneration;
    final current = albumState(album.id);
    final allRated = albumAverageStars(tracks) != null;
    final allListened = tracks.isNotEmpty && tracks.every(
      (track) => trackState(track.id).isListened);
    final normalized = allRated && allListened && !current.isListened
        ? current.copyWith(isListened: true,
            listenedAt: current.listenedAt ?? DateTime.now().toUtc(),
            libraryStatus: null)
        : current;
    final next = _derivedAlbumRating(normalized, tracks);
    if (current.rating == next.rating &&
        current.isListened == next.isListened){ return;}
    await _upsertAlbum(album, tracks, next,
        expectedGeneration: generation, expectedUserId: user.id);
    if (!_sessionStillCurrent(generation, user.id)) return;
    _cache[_key('album', album.id)] = next;
    notifyListeners();
  });

  Future<void> setTrackRating({
    required MusicAlbum album,
    required List<MusicTrack> allTracks,
    required MusicTrack track,
    required int? stars,
  }) => _serializeSave(() async {
    final user = _requireUser();
    final generation = _stateGeneration;

    if (stars != null && (stars < 1 || stars > 5)) {
      throw ArgumentError.value(stars, 'stars', 'Rating must be 1–5.');
    }

    final current = trackState(track.id);
    final now = DateTime.now().toUtc();
    final autoListen = stars != null && !current.isListened;
    final next = current.copyWith(
      rating: stars == null ? null : stars * 2,
      ratedAt: stars == null ? null : now,
      isListened: autoListen ? true : current.isListened,
      listenedAt: autoListen ? (current.listenedAt ?? now) : current.listenedAt,
    );

    await _persistTrackInteraction(
      album: album,
      allTracks: allTracks,
      track: track,
      next: next,
      autoListen: autoListen,
      expectedGeneration: generation,
      expectedUserId: user.id,
    );
  });

  // One write keeps the auto-listened song and (when relevant) its completed
  // album in sync. An action failing in Supabase leaves both records untouched.
  Future<void> _persistTrackInteraction({
    required MusicAlbum album,
    required List<MusicTrack> allTracks,
    required MusicTrack track,
    required MusicUserDataState next,
    required bool autoListen,
    required int expectedGeneration,
    required String expectedUserId,
  }) async {
    if (!autoListen) {
      final ratingChanged = trackState(track.id).rating != next.rating;
      if (ratingChanged) {
        final currentAlbum = albumState(album.id);
        final complete = allTracks.isNotEmpty && allTracks.every(
          (item) => item.id == track.id ? next.isListened
              : trackState(item.id).isListened);
        final nextAlbum = _derivedAlbumRating(currentAlbum.copyWith(
          isListened: complete,
          listenedAt: complete
              ? (currentAlbum.listenedAt ?? DateTime.now().toUtc()) : null,
          libraryStatus: complete ? null : currentAlbum.libraryStatus,
        ), allTracks, changedTrackId: track.id, changedState: next);
        final rows = <Map<String, dynamic>>[
          _trackRow(album, track, next),
          _albumRow(album, allTracks, nextAlbum),
        ];
        await client.from('music_user_data').upsert(rows,
            onConflict: 'user_id,entity_type,entity_id');
        if (!_sessionStillCurrent(expectedGeneration, expectedUserId)) return;
        for (final row in rows) { _rememberCommittedRow(row); }
        _cache[_key('track', track.id)] = next;
        _cache[_key('album', album.id)] = nextAlbum;
      } else {
        await _upsertTrack(album, track, next,
            expectedGeneration: expectedGeneration,
            expectedUserId: expectedUserId);
        if (!_sessionStillCurrent(expectedGeneration, expectedUserId)) return;
        _cache[_key('track', track.id)] = next;
      }
      notifyListeners();
      return;
    }

    final currentAlbum = albumState(album.id);
    final allListened = allTracks.isNotEmpty && allTracks.every(
      (item) => item.id == track.id || trackState(item.id).isListened,
    );
    final now = DateTime.now().toUtc();
    final nextAlbum = _derivedAlbumRating(
      currentAlbum.copyWith(
        isListened: allListened,
        listenedAt: allListened ? (currentAlbum.listenedAt ?? now) : null,
        libraryStatus: null,
      ), allTracks, changedTrackId: track.id, changedState: next,
    );
    final rows = <Map<String, dynamic>>[
      _trackRow(album, track, next),
      _albumRow(album, allTracks, nextAlbum),
    ];
    await client.from('music_user_data').upsert(
      rows,
      onConflict: 'user_id,entity_type,entity_id',
    );
    if (!_sessionStillCurrent(expectedGeneration, expectedUserId)) return;
    for (final row in rows) {
      _rememberCommittedRow(row);
    }
    _cache[_key('track', track.id)] = next;
    _cache[_key('album', album.id)] = nextAlbum;
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

    _rememberCommittedRow(row);
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

    _rememberCommittedRow(row);
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

    final key = _key(entityType, entityId);
    _allRows[key] = Map<String, dynamic>.from(row);
    _cache[key] = _stateFromRow(row);
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
    _cachedUserId = null;
    _stateGeneration++;
    _cache.clear();
    _allRows.clear();
    _lastAppliedRequest.clear();
    _lastSavedRevision.clear();
    _pendingLoadAll = null;
    _pendingLoadUserId = null;
    notifyListeners();
  }
}
