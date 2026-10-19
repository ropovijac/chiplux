import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService extends ChangeNotifier {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  SupabaseClient get client => Supabase.instance.client;

  String displayName = '';
  String username = '';
  String? avatarUrl;

  bool isDeveloper = false;
  // Server-verified, single-account reward entitlement (not achievement progress).
  bool hasDeveloperRewardAccess = false;
  bool followedDeveloperAchievement = false;

  int? bannerTmdbId;
  String? bannerMediaType;
  String? bannerPath;

  bool isLoading = false;

  String? get bannerUrl {
    final path = bannerPath;

    if (path == null || path.trim().isEmpty) {
      return null;
    }

    return 'https://image.tmdb.org/t/p/w1280$path';
  }

  Future<void> loadProfile() async {
    final user = client.auth.currentUser;

    if (user == null) {
      clear();
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // Always overwrite local state.
      //
      // This is important when switching
      // between different accounts.
      displayName = data?['display_name']?.toString() ?? '';

      username = data?['username']?.toString() ?? '';

      avatarUrl = data?['avatar_url']?.toString();

      isDeveloper = data?['is_developer'] == true;

      // The RPC checks the *authenticated user* against a private server-side
      // allowlist. Do not derive exclusive reward access from a local boolean.
      hasDeveloperRewardAccess = false;
      if (isDeveloper) {
        try {
          hasDeveloperRewardAccess =
              await client.rpc('chiplux_my_reward_access') == true;
        } catch (error) {
          debugPrint('Could not verify developer reward entitlement: $error');
        }
      }

      followedDeveloperAchievement =
          data?['followed_developer_achievement'] == true;

      final rawBannerId = data?['banner_tmdb_id'];

      bannerTmdbId = rawBannerId is num ? rawBannerId.toInt() : null;

      bannerMediaType = data?['banner_media_type']?.toString();

      bannerPath = data?['banner_path']?.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String username,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final cleanUsername = username.trim().toLowerCase();

    await client
        .from('profiles')
        .update({
          'display_name': displayName.trim(),
          'username': cleanUsername.isEmpty ? null : cleanUsername,
        })
        .eq('id', user.id);

    this.displayName = displayName.trim();

    this.username = cleanUsername;

    notifyListeners();
  }

  Future<void> updateAvatarUrl(String? value) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    await client
        .from('profiles')
        .update({'avatar_url': value})
        .eq('id', user.id);

    avatarUrl = value;
    notifyListeners();
  }

  Future<void> updateBanner({
    required int tmdbId,
    required String mediaType,
    required String bannerPath,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    bannerTmdbId = tmdbId;

    bannerMediaType = mediaType;

    this.bannerPath = bannerPath;

    notifyListeners();

    await client
        .from('profiles')
        .update({
          'banner_tmdb_id': tmdbId,
          'banner_media_type': mediaType,
          'banner_path': bannerPath,
        })
        .eq('id', user.id);
  }

  Future<void> removeBanner() async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    bannerTmdbId = null;

    bannerMediaType = null;

    bannerPath = null;

    notifyListeners();

    await client
        .from('profiles')
        .update({
          'banner_tmdb_id': null,
          'banner_media_type': null,
          'banner_path': null,
        })
        .eq('id', user.id);
  }

  Future<bool> claimFollowDeveloperAchievement() async {
    final user = client.auth.currentUser;

    if (user == null) {
      return false;
    }

    if (isDeveloper || followedDeveloperAchievement) {
      return false;
    }

    await client
        .from('profiles')
        .update({'followed_developer_achievement': true})
        .eq('id', user.id);

    final data = await client
        .from('profiles')
        .select('followed_developer_achievement')
        .eq('id', user.id)
        .maybeSingle();

    final unlocked = data?['followed_developer_achievement'] == true;

    if (!unlocked) {
      return false;
    }

    followedDeveloperAchievement = true;

    notifyListeners();

    return true;
  }

  void clear() {
    displayName = '';
    username = '';

    avatarUrl = null;

    isDeveloper = false;
    hasDeveloperRewardAccess = false;

    bannerTmdbId = null;

    bannerMediaType = null;

    bannerPath = null;

    isLoading = false;

    followedDeveloperAchievement = false;

    notifyListeners();
  }
}
