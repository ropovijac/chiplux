import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'library_service.dart';

/// A global, admin-authored, one-tier movie achievement.
/// Movie IDs are TMDB movie IDs (not TV IDs or title strings).
class CustomMovieAchievement {
  final String id;
  final String name;
  final String description;
  final String rewardTitle;
  final List<int> movieIds;
  final Map<int, String> movieTitles;
  final int iconSlot;
  final String? iconifyId;
  final bool isActive;

  const CustomMovieAchievement({
    required this.id,
    required this.name,
    required this.description,
    required this.rewardTitle,
    required this.movieIds,
    required this.movieTitles,
    required this.iconSlot,
    this.iconifyId,
    required this.isActive,
  });

  factory CustomMovieAchievement.fromJson(Map<String, dynamic> row) {
    final names = <int, String>{};
    if (row['movie_titles'] is Map) {
      for (final entry in (row['movie_titles'] as Map).entries) {
        final id = int.tryParse(entry.key.toString());
        if (id != null) names[id] = entry.value.toString();
      }
    }
    return CustomMovieAchievement(
      id: row['id'].toString(),
      name: row['name'].toString(),
      description: row['description'].toString(),
      rewardTitle: row['reward_title'].toString(),
      movieIds: (row['movie_ids'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toInt()).toList(growable: false),
      movieTitles: names,
      iconSlot: (row['icon_slot'] as num).toInt(),
      iconifyId: row['iconify_id']?.toString(),
      isActive: row['is_active'] == true,
    );
  }
}

/// Admin definitions are shared among users. Unlocks are reconciled against
/// CURRENT cloud-library completions, including whenever requirements change.
class CustomMovieAchievementService extends ChangeNotifier with WidgetsBindingObserver {
  CustomMovieAchievementService._() {
    LibraryService.instance.addListener(_onLibraryChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId != null) {
      unawaited(load());
    }
  }

  static final instance = CustomMovieAchievementService._();
  static const maxIconSlots = 16;

  List<CustomMovieAchievement> _definitions = const [];
  Set<String> _claimed = {};
  Set<int> _completedMovieIds = {};
  final Set<String> _pendingClaims = {};
  // UI consumption queue. Popups are still deduplicated cross-device by the
  // separate, authoritative achievement-popup receipt RPC in main.dart.
  final List<String> _newlyClaimedIds = <String>[];
  bool get hasPendingNewUnlocks => _newlyClaimedIds.isNotEmpty;
  List<String> takeNewUnlockIds() {
    final result = List<String>.from(_newlyClaimedIds);
    _newlyClaimedIds.clear();
    return result;
  }

  void _queueNewUnlock(String achievementId) {
    if (!_newlyClaimedIds.contains(achievementId)) {
      _newlyClaimedIds.add(achievementId);
    }
  }

  String? _userId;
  bool _loaded = false;
  bool get loaded => _loaded;
  List<CustomMovieAchievement> get definitions => List.unmodifiable(_definitions);
  List<CustomMovieAchievement> get activeDefinitions =>
      List.unmodifiable(_definitions.where((entry) => entry.isActive));

  int progress(CustomMovieAchievement achievement) {
    return achievement.movieIds.where(_completedMovieIds.contains).length;
  }

  bool unlocked(CustomMovieAchievement achievement) =>
      achievement.isActive && _claimed.contains(achievement.id) &&
      progress(achievement) == achievement.movieIds.length;

  bool hasWatched(int movieId) => _completedMovieIds.contains(movieId);

  CustomMovieAchievement? byGroupId(String groupId) {
    if (!groupId.startsWith('custom_movie_')) return null;
    final id = groupId.substring('custom_movie_'.length);
    for (final definition in _definitions) {
      if (definition.id == id && definition.isActive) return definition;
    }
    return null;
  }

  void _onLibraryChanged() {
    final completed = LibraryService.instance.items
        .where((item) => item.mediaType == 'movie' && item.status == 'completed')
        .map((item) => item.id).toSet();
    if (setEquals(completed, _completedMovieIds)) return;
    _completedMovieIds = completed;
    notifyListeners();
    _claimCompleted();
  }

  Future<void> load() async {
    final user = Supabase.instance.client.auth.currentUser;
    final accountId = user?.id;
    final sameLoadedAccount = _loaded && accountId != null && _userId == accountId;
    final priorClaims = sameLoadedAccount ? Set<String>.from(_claimed) : <String>{};
    if (_userId != accountId) {
      _newlyClaimedIds.clear();
      _claimed = {};
      _definitions = const [];
    }
    _userId = accountId;
    _loaded = false;
    _onLibraryChanged();
    if (accountId == null) {
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      // Refresh server-verified unlocks before reading definitions. The SQL
      // migration also reconciles all affected accounts on admin edits.
      await Supabase.instance.client.rpc('chiplux_recalculate_my_custom_movie_unlocks');
      final responses = await Future.wait<dynamic>([
        // RLS exposes drafts only to allowlisted administrators.
        Supabase.instance.client.from('chiplux_custom_movie_achievements')
            .select('id,name,description,reward_title,movie_ids,movie_titles,icon_slot,iconify_id,is_active')
            .order('created_at', ascending: true),
        Supabase.instance.client.from('chiplux_custom_movie_unlocks')
            .select('achievement_id').eq('user_id', accountId),
      ]);
      // Do not apply network responses from an account that signed out.
      if (_userId != accountId || Supabase.instance.client.auth.currentUser?.id != accountId) return;
      _definitions = (responses[0] as List<dynamic>)
          .whereType<Map>()
          .map((value) => CustomMovieAchievement.fromJson(Map<String, dynamic>.from(value)))
          .toList(growable: false);
      _claimed = (responses[1] as List<dynamic>)
          .whereType<Map>()
          .map((value) => value['achievement_id'].toString()).toSet();
      _loaded = true;
      if (sameLoadedAccount) {
        for (final def in activeDefinitions) {
          if (_claimed.contains(def.id) && !priorClaims.contains(def.id) &&
              def.movieIds.every(_completedMovieIds.contains)) {
            _queueNewUnlock(def.id);
          }
        }
      }
      notifyListeners();
      _claimCompleted();
    } catch (error) {
      _loaded = true;
      debugPrint('Could not fetch custom movie achievements: $error');
      notifyListeners();
      // The rest of Chiplux must remain usable if migration is not installed.
    }
  }

  void _claimCompleted() {
    final accountId = _userId;
    if (!_loaded || accountId == null) return;
    for (final achievement in activeDefinitions) {
      if (!_claimed.contains(achievement.id) &&
          !_pendingClaims.contains(achievement.id) &&
          achievement.movieIds.every(_completedMovieIds.contains)) {
        unawaited(_claim(achievement.id, accountId));
      }
    }
  }

  Future<void> _claim(String achievementId, String accountId) async {
    _pendingClaims.add(achievementId);
    try {
      // Library writes can still be synchronizing when a movie is checked.
      // The RPC verifies all TMDB IDs against the user's cloud Library.
      for (var attempt = 0; attempt < 3; attempt++) {
        if (_userId != accountId ||
            Supabase.instance.client.auth.currentUser?.id != accountId) {break;} 
        if (attempt > 0) {
          await Future<void>.delayed(Duration(seconds: attempt * 3));
        }
        final claimed = await Supabase.instance.client.rpc(
          'chiplux_claim_custom_movie_achievement',
          params: {'p_achievement_id': achievementId},
        );
        if (claimed == true) {
          if (_userId == accountId &&
              activeDefinitions.any((def) => def.id == achievementId &&
                  def.movieIds.every(_completedMovieIds.contains))) {
            if (_claimed.add(achievementId)) {
              _queueNewUnlock(achievementId);
            }
            notifyListeners();
          }
          break;
        }
      }
    } catch (error) {
      debugPrint('Custom movie achievement claim failed: $error');
    } finally {
      _pendingClaims.remove(achievementId);
    }
  }

  Future<void> create({
    required String name,
    required String description,
    required String rewardTitle,
    required Map<int, String> requiredMovies,
    String? iconifyId,
  }) async {
    _validateIcon(iconifyId);
    _validateFields(name, description, rewardTitle, requiredMovies);
    // Unique icon slot for each admin achievement. Concurrent inserts are
    // protected by a database UNIQUE index; refresh if the slot was taken.
    final used = _definitions.map((entry) => entry.iconSlot).toSet();
    final available = List.generate(maxIconSlots, (i) => i)
        .where((slot) => !used.contains(slot)).toList();
    if (available.isEmpty) {
      throw StateError('All $maxIconSlots unique custom achievement icon pairs are in use.');
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to create an achievement.');
    await Supabase.instance.client.from('chiplux_custom_movie_achievements').insert({
      'name': name.trim(),
      'description': description.trim(),
      'reward_title': rewardTitle.trim(),
      'movie_ids': requiredMovies.keys.toList(growable: false),
      'movie_titles': {for (final entry in requiredMovies.entries) '${entry.key}': entry.value},
      'icon_slot': available.first,
      'iconify_id': iconifyId,
      'created_by': userId,
    });
    await load();
  }

  /// Replace the whole editable definition. The backend reconciles every
  /// user's entitlement in the same transaction and revokes invalid titles.
  Future<void> updateAchievement({
    required CustomMovieAchievement achievement,
    required String name,
    required String description,
    required String rewardTitle,
    required Map<int, String> requiredMovies,
    String? iconifyId,
  }) async {
    _validateIcon(iconifyId);
    _validateFields(name, description, rewardTitle, requiredMovies);
    await Supabase.instance.client
        .from('chiplux_custom_movie_achievements')
        .update({
          'name': name.trim(),
          'description': description.trim(),
          'reward_title': rewardTitle.trim(),
          'iconify_id': iconifyId,
          'movie_ids': requiredMovies.keys.toList(growable: false),
          'movie_titles': {
            for (final entry in requiredMovies.entries) '${entry.key}': entry.value,
          },
        })
        .eq('id', achievement.id);
    await load();
  }

  /// Unpublishing hides the achievement and temporarily removes access to its
  /// title, without deleting its definition/unlock history.
  Future<void> setPublished(CustomMovieAchievement achievement, bool published) async {
    await Supabase.instance.client
        .from('chiplux_custom_movie_achievements')
        .update({'is_active': published})
        .eq('id', achievement.id);
    await load();
  }

  /// Permanent deletion cascades to claimed unlock rows and removes any
  /// equipped Profile Title. Icon slots become available for future groups.
  Future<void> deleteAchievement(CustomMovieAchievement achievement) async {
    await Supabase.instance.client
        .from('chiplux_custom_movie_achievements')
        .delete()
        .eq('id', achievement.id);
    await load();
  }

  // Only the audited open-license icon sets offered by the picker can be saved.
  void _validateIcon(String? iconifyId) {
    if (iconifyId == null) return;
    if (!RegExp(r'^(lucide|tabler|mdi):[a-z0-9]+(?:-[a-z0-9]+)*$')
            .hasMatch(iconifyId) || iconifyId.length > 120) {
      throw ArgumentError('Select a supported icon from the library.');
    }
  }

  void _validateFields(
    String name,
    String description,
    String rewardTitle,
    Map<int, String> requiredMovies,
  ) {
    if (name.trim().isEmpty || description.trim().isEmpty ||
        rewardTitle.trim().isEmpty || requiredMovies.isEmpty) {
      throw ArgumentError('Add a name, description, title reward and at least one movie.');
    }
    if (name.trim().length > 80 || description.trim().length > 500 ||
        rewardTitle.trim().length > 60 || requiredMovies.length > 100 ||
        requiredMovies.keys.any((id) => id <= 0)) {
      throw ArgumentError('An achievement exceeds its field or movie limits.');
    }
  }

  void clear() {
    _userId = null;
    _definitions = const [];
    _claimed = {};
    _loaded = false;
    _pendingClaims.clear();
    notifyListeners();
  }
}
