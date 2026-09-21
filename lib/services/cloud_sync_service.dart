import 'package:supabase_flutter/supabase_flutter.dart';

class CloudSyncService {
  CloudSyncService._();

  static final CloudSyncService instance =
      CloudSyncService._();

  SupabaseClient get client =>
      Supabase.instance.client;

  User? get user =>
      client.auth.currentUser;

  bool get isLoggedIn =>
      user != null;

  // =====================================================
  // LIBRARY UPLOAD
  // =====================================================

  Future<void> uploadLibrary(
    List<Map<String, dynamic>> items,
  ) async {
    final currentUser = user;

    if (currentUser == null) {
      return;
    }

    // Read current cloud state first.
    final cloudItems =
        await downloadLibrary();

    String localKey(
      Map<String, dynamic> item,
    ) {
      return '${item['mediaType']}:${item['id']}';
    }

    String cloudKey(
      Map<String, dynamic> item,
    ) {
      return '${item['media_type']}:${item['tmdb_id']}';
    }

    final localKeys =
        items.map(localKey).toSet();

    final rows =
        items.map(
      (item) {
        return {
          'user_id':
              currentUser.id,
          'tmdb_id':
              item['id'],
          'media_type':
              item['mediaType'],
          'title':
              item['title'],
          'poster_path':
              item['posterPath'],
          'year':
              item['year'],
          'status':
              item['status'],
          'total_episodes':
              item['totalEpisodes'],
          'runtime_minutes':
              item['runtimeMinutes'] ??
                  0,
          'genre_ids':
              item['genreIds'] ??
                  [],
          'added_at':
              item['addedAt'],
        };
      },
    ).toList();

    // -----------------------------------------
    // UPSERT FIRST
    // -----------------------------------------

    const int batchSize = 500;

    for (int i = 0;
        i < rows.length;
        i += batchSize) {
      final int end =
          (i + batchSize <
                  rows.length)
              ? i + batchSize
              : rows.length;

      final batch =
          rows.sublist(
        i,
        end,
      );

      await client
          .from(
            'library_items',
          )
          .upsert(
            batch,
            onConflict:
                'user_id,tmdb_id,media_type',
          );
    }

    // -----------------------------------------
    // DELETE ONLY STALE CLOUD ITEMS
    // -----------------------------------------

    final staleItems =
        cloudItems.where(
      (item) {
        return !localKeys.contains(
          cloudKey(
            item,
          ),
        );
      },
    ).toList();

    for (final item
        in staleItems) {
      await client
          .from(
            'library_items',
          )
          .delete()
          .eq(
            'user_id',
            currentUser.id,
          )
          .eq(
            'tmdb_id',
            item['tmdb_id'],
          )
          .eq(
            'media_type',
            item['media_type'],
          );
    }
  }

  // =====================================================
  // EPISODE UPLOAD
  // =====================================================

  Future<void> uploadEpisodes(
    List<Map<String, int>> episodes,
  ) async {
    final currentUser = user;

    if (currentUser == null) {
      return;
    }

    final cloudEpisodes =
        await downloadEpisodes();

    String localKey(
      Map<String, int> episode,
    ) {
      return '${episode['showId']}:'
          '${episode['seasonNumber']}:'
          '${episode['episodeNumber']}';
    }

    String cloudKey(
      Map<String, dynamic> episode,
    ) {
      return '${episode['show_id']}:'
          '${episode['season_number']}:'
          '${episode['episode_number']}';
    }

    final localKeys =
        episodes
            .map(localKey)
            .toSet();

    final rows =
        episodes.map(
      (episode) {
        return {
          'user_id':
              currentUser.id,
          'show_id':
              episode['showId'],
          'season_number':
              episode[
                  'seasonNumber'],
          'episode_number':
              episode[
                  'episodeNumber'],
          'runtime_minutes':
              episode[
                      'runtimeMinutes'] ??
                  0,
        };
      },
    ).toList();

    // -----------------------------------------
    // UPSERT FIRST
    // -----------------------------------------

    const int batchSize = 500;

    for (int i = 0;
        i < rows.length;
        i += batchSize) {
      final int end =
          (i + batchSize <
                  rows.length)
              ? i + batchSize
              : rows.length;

      final batch =
          rows.sublist(
        i,
        end,
      );

      await client
          .from(
            'watched_episodes',
          )
          .upsert(
            batch,
            onConflict:
                'user_id,show_id,season_number,episode_number',
          );
    }

    // -----------------------------------------
    // DELETE ONLY UNWATCHED EPISODES
    // -----------------------------------------

    final staleEpisodes =
        cloudEpisodes.where(
      (episode) {
        return !localKeys.contains(
          cloudKey(
            episode,
          ),
        );
      },
    ).toList();

    for (final episode
        in staleEpisodes) {
      await client
          .from(
            'watched_episodes',
          )
          .delete()
          .eq(
            'user_id',
            currentUser.id,
          )
          .eq(
            'show_id',
            episode['show_id'],
          )
          .eq(
            'season_number',
            episode[
                'season_number'],
          )
          .eq(
            'episode_number',
            episode[
                'episode_number'],
          );
    }
  }

  // =====================================================
  // LIBRARY DOWNLOAD
  // =====================================================

  Future<List<Map<String, dynamic>>>
      downloadLibrary() async {
    final currentUser = user;

    if (currentUser == null) {
      return [];
    }

    const int pageSize = 1000;

    final List<Map<String, dynamic>>
        allItems = [];

    int from = 0;

    while (true) {
      final data = await client
          .from(
            'library_items',
          )
          .select()
          .eq(
            'user_id',
            currentUser.id,
          )
          .order(
            'media_type',
          )
          .order(
            'tmdb_id',
          )
          .range(
            from,
            from + pageSize - 1,
          );

      final page =
          List<Map<String, dynamic>>
              .from(
        data,
      );

      allItems.addAll(
        page,
      );

      if (page.length <
          pageSize) {
        break;
      }

      from += pageSize;
    }

    return allItems;
  }

  // =====================================================
  // EPISODE DOWNLOAD
  // =====================================================

  Future<List<Map<String, dynamic>>>
      downloadEpisodes() async {
    final currentUser = user;

    if (currentUser == null) {
      return [];
    }

    const int pageSize = 1000;

    final List<Map<String, dynamic>>
        allEpisodes = [];

    int from = 0;

    while (true) {
      final data = await client
          .from(
            'watched_episodes',
          )
          .select()
          .eq(
            'user_id',
            currentUser.id,
          )
          .order(
            'show_id',
          )
          .order(
            'season_number',
          )
          .order(
            'episode_number',
          )
          .range(
            from,
            from + pageSize - 1,
          );

      final page =
          List<Map<String, dynamic>>
              .from(
        data,
      );

      allEpisodes.addAll(
        page,
      );

      if (page.length <
          pageSize) {
        break;
      }

      from += pageSize;
    }

    return allEpisodes;
  }
}