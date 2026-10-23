import 'package:supabase_flutter/supabase_flutter.dart';

class CloudSyncService {
  CloudSyncService._();

  static final CloudSyncService instance = CloudSyncService._();

  SupabaseClient get client => Supabase.instance.client;

  User? get user => client.auth.currentUser;

  bool get isLoggedIn => user != null;

  // =====================================================
  // LIBRARY UPLOAD
  // =====================================================

  Future<void> uploadLibrary(List<Map<String, dynamic>> items) async {
    final currentUser = user;

    if (currentUser == null) {
      return;
    }

    // Read current cloud state first.
    final cloudItems = await downloadLibrary();

    String localKey(Map<String, dynamic> item) {
      return '${item['mediaType']}:${item['id']}';
    }

    String cloudKey(Map<String, dynamic> item) {
      return '${item['media_type']}:${item['tmdb_id']}';
    }

    final localKeys = items.map(localKey).toSet();

    final rows = items.map((item) {
      return {
        'user_id': currentUser.id,
        'tmdb_id': item['id'],
        'media_type': item['mediaType'],
        'title': item['title'],
        'poster_path': item['posterPath'],
        'year': item['year'],
        'status': item['status'],
        'total_episodes': item['totalEpisodes'],
        'runtime_minutes': item['runtimeMinutes'] ?? 0,
        'genre_ids': item['genreIds'] ?? [],
        'added_at': item['addedAt'],
      };
    }).toList();

    // -----------------------------------------
    // UPSERT FIRST
    // -----------------------------------------

    const int batchSize = 500;

    for (int i = 0; i < rows.length; i += batchSize) {
      final int end = (i + batchSize < rows.length)
          ? i + batchSize
          : rows.length;

      final batch = rows.sublist(i, end);

      await client
          .from('library_items')
          .upsert(batch, onConflict: 'user_id,tmdb_id,media_type');
    }

    // -----------------------------------------
    // DELETE ONLY STALE CLOUD ITEMS
    // -----------------------------------------

    final staleItems = cloudItems.where((item) {
      return !localKeys.contains(cloudKey(item));
    }).toList();

    for (final item in staleItems) {
      await client
          .from('library_items')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('tmdb_id', item['tmdb_id'])
          .eq('media_type', item['media_type']);
    }
  }

  // =====================================================
  // EPISODE UPLOAD
  // =====================================================

  Future<void> uploadEpisodes(List<Map<String, int>> episodes) async {
    final currentUser = user;

    if (currentUser == null) {
      return;
    }

    final cloudEpisodes = await downloadEpisodes();

    String localKey(Map<String, int> episode) {
      return '${episode['showId']}:'
          '${episode['seasonNumber']}:'
          '${episode['episodeNumber']}';
    }

    String cloudKey(Map<String, dynamic> episode) {
      return '${episode['show_id']}:'
          '${episode['season_number']}:'
          '${episode['episode_number']}';
    }

    final localKeys = episodes.map(localKey).toSet();

    final rows = episodes.map((episode) {
      return {
        'user_id': currentUser.id,
        'show_id': episode['showId'],
        'season_number': episode['seasonNumber'],
        'episode_number': episode['episodeNumber'],
        'runtime_minutes': episode['runtimeMinutes'] ?? 0,
      };
    }).toList();

    // -----------------------------------------
    // UPSERT FIRST
    // -----------------------------------------

    const int batchSize = 500;

    for (int i = 0; i < rows.length; i += batchSize) {
      final int end = (i + batchSize < rows.length)
          ? i + batchSize
          : rows.length;

      final batch = rows.sublist(i, end);

      await client
          .from('watched_episodes')
          .upsert(
            batch,
            onConflict: 'user_id,show_id,season_number,episode_number',
          );
    }

    // -----------------------------------------
    // DELETE ONLY UNWATCHED EPISODES
    // -----------------------------------------

    final staleEpisodes = cloudEpisodes.where((episode) {
      return !localKeys.contains(cloudKey(episode));
    }).toList();

    for (final episode in staleEpisodes) {
      await client
          .from('watched_episodes')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('show_id', episode['show_id'])
          .eq('season_number', episode['season_number'])
          .eq('episode_number', episode['episode_number']);
    }
  }

  // =====================================================
  // INCREMENTAL LIBRARY / EPISODE WRITES
  // =====================================================

  // These methods never list the whole server collection or delete records
  // other than the explicit keys supplied by LibraryService's per-user diff.
  // The caller retries the same idempotent operations after a partial failure.
  // RLS still protects each row; an account switch fails closed.
  void _assertAccount(String expectedUserId) {
    if (user?.id != expectedUserId) {
      throw StateError('Account changed during Library synchronization.');
    }
  }

  Future<void> uploadLibraryChanges({
    required String userId,
    required List<Map<String, dynamic>> upserts,
    required List<Map<String, dynamic>> deletes,
  }) async {
    _assertAccount(userId);
    const batchSize = 250;
    final rows = [
      for (final item in upserts)
        {
          'user_id': userId,
          'tmdb_id': item['id'],
          'media_type': item['mediaType'],
          'title': item['title'],
          'poster_path': item['posterPath'],
          'year': item['year'],
          'status': item['status'],
          'total_episodes': item['totalEpisodes'],
          'runtime_minutes': item['runtimeMinutes'] ?? 0,
          'genre_ids': item['genreIds'] ?? [],
          'added_at': item['addedAt'],
        },
    ];

    for (var i = 0; i < rows.length; i += batchSize) {
      _assertAccount(userId);
      final end = i + batchSize < rows.length ? i + batchSize : rows.length;
      await client.from('library_items').upsert(
        rows.sublist(i, end),
        onConflict: 'user_id,tmdb_id,media_type',
      );
    }
    for (final item in deletes) {
      _assertAccount(userId);
      await client.from('library_items').delete()
          .eq('user_id', userId)
          .eq('tmdb_id', item['id'])
          .eq('media_type', item['mediaType']);
    }
    _assertAccount(userId);
  }

  /// Make one locally watched episode visible to database rating triggers.
  /// Existing cloud runtime/progress are preserved if the row already exists.
  /// This is idempotent and does not mark any untracked episode as watched.
  Future<void> ensureWatchedEpisode({
    required String userId,
    required int showId,
    required int seasonNumber,
    required int episodeNumber,
    required int runtimeMinutes,
  }) async {
    _assertAccount(userId);
    await client.from('watched_episodes').upsert(
      {
        'user_id': userId,
        'show_id': showId,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        'runtime_minutes': runtimeMinutes,
      },
      onConflict: 'user_id,show_id,season_number,episode_number',
      ignoreDuplicates: true,
    );
    _assertAccount(userId);
  }

  Future<void> uploadEpisodeChanges({
    required String userId,
    required List<Map<String, int>> upserts,
    required List<Map<String, int>> deletes,
  }) async {
    _assertAccount(userId);
    const batchSize = 250;
    final rows = [
      for (final episode in upserts)
        {
          'user_id': userId,
          'show_id': episode['showId'],
          'season_number': episode['seasonNumber'],
          'episode_number': episode['episodeNumber'],
          'runtime_minutes': episode['runtimeMinutes'] ?? 0,
        },
    ];
    for (var i = 0; i < rows.length; i += batchSize) {
      _assertAccount(userId);
      final end = i + batchSize < rows.length ? i + batchSize : rows.length;
      await client.from('watched_episodes').upsert(
        rows.sublist(i, end),
        onConflict: 'user_id,show_id,season_number,episode_number',
      );
    }
    for (final episode in deletes) {
      _assertAccount(userId);
      // Supabase filters require non-null identifiers. Fail safely rather
      // than silently deleting the wrong episode when metadata is malformed.
      final showId = episode['showId'];
      final seasonNumber = episode['seasonNumber'];
      final episodeNumber = episode['episodeNumber'];
      if (showId == null || seasonNumber == null || episodeNumber == null) {
        throw StateError('Cannot delete an episode without its identifying fields.');
      }
      await client.from('watched_episodes').delete()
          .eq('user_id', userId)
          .eq('show_id', showId)
          .eq('season_number', seasonNumber)
          .eq('episode_number', episodeNumber);
    }
    _assertAccount(userId);
  }

  // =====================================================
  // LIBRARY DOWNLOAD
  // =====================================================

  Future<List<Map<String, dynamic>>> downloadLibrary() async {
    final currentUser = user;

    if (currentUser == null) {
      return [];
    }

    const int pageSize = 1000;

    final List<Map<String, dynamic>> allItems = [];

    int from = 0;

    while (true) {
      final data = await client
          .from('library_items')
          .select()
          .eq('user_id', currentUser.id)
          .order('media_type')
          .order('tmdb_id')
          .range(from, from + pageSize - 1);

      final page = List<Map<String, dynamic>>.from(data);

      allItems.addAll(page);

      if (page.length < pageSize) {
        break;
      }

      from += pageSize;
    }

    return allItems;
  }

  // =====================================================
  // EPISODE DOWNLOAD
  // =====================================================

  Future<List<Map<String, dynamic>>> downloadEpisodes() async {
    final currentUser = user;

    if (currentUser == null) {
      return [];
    }

    const int pageSize = 1000;

    final List<Map<String, dynamic>> allEpisodes = [];

    int from = 0;

    while (true) {
      final data = await client
          .from('watched_episodes')
          .select()
          .eq('user_id', currentUser.id)
          .order('show_id')
          .order('season_number')
          .order('episode_number')
          .range(from, from + pageSize - 1);

      final page = List<Map<String, dynamic>>.from(data);

      allEpisodes.addAll(page);

      if (page.length < pageSize) {
        break;
      }

      from += pageSize;
    }

    return allEpisodes;
  }
}
