import 'package:supabase_flutter/supabase_flutter.dart';

class FeatureSubmissionAvailability {
  final bool allowed;
  final DateTime? lastSubmittedAt;
  final DateTime? nextAllowedAt;

  const FeatureSubmissionAvailability({
    required this.allowed,
    required this.lastSubmittedAt,
    required this.nextAllowedAt,
  });
}

class FeatureSuggestionService {
  FeatureSuggestionService._();

  static final FeatureSuggestionService instance = FeatureSuggestionService._();

  SupabaseClient get client => Supabase.instance.client;

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  Future<FeatureSubmissionAvailability> getSubmissionAvailability() async {
    final raw = await client.rpc('get_feature_suggestion_submission_status');

    Map<String, dynamic>? row;

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      row = Map<String, dynamic>.from(raw.first as Map);
    } else if (raw is Map) {
      row = Map<String, dynamic>.from(raw);
    }

    return FeatureSubmissionAvailability(
      allowed: row?['allowed'] == true,
      lastSubmittedAt: _parseDate(row?['last_submitted_at']),
      nextAllowedAt: _parseDate(row?['next_allowed_at']),
    );
  }

  Future<String> submitSuggestion({
    required String title,
    required String description,
    required bool publicAttribution,
  }) async {
    final result = await client.rpc(
      'submit_feature_suggestion',
      params: {
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_public_attribution': publicAttribution,
      },
    );

    return result?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> loadPublicSuggestions() async {
    final user = client.auth.currentUser;

    final rawSuggestions = await client
        .from('feature_suggestions')
        .select()
        .neq('status', 'pending')
        .order('status_changed_at', ascending: false)
        .limit(100);

    final suggestions = List<Map<String, dynamic>>.from(rawSuggestions);

    if (suggestions.isEmpty) {
      return [];
    }

    final featureIds = suggestions
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();

    final userIds = suggestions
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final rawLikes = featureIds.isEmpty
        ? <dynamic>[]
        : await client
              .from('feature_suggestion_likes')
              .select('feature_id, user_id, created_at')
              .inFilter('feature_id', featureIds);

    final rawComments = featureIds.isEmpty
        ? <dynamic>[]
        : await client
              .from('feature_suggestion_comments')
              .select('id, feature_id, user_id, body, created_at')
              .inFilter('feature_id', featureIds)
              .order('created_at', ascending: true);

    final rawProfiles = userIds.isEmpty
        ? <dynamic>[]
        : await client
              .from('profiles')
              .select(
                'id, display_name, username, avatar_url, '
                'privacy_feature_suggestion_attribution',
              )
              .inFilter('id', userIds);

    final likes = List<Map<String, dynamic>>.from(rawLikes);
    final comments = List<Map<String, dynamic>>.from(rawComments);
    final profiles = List<Map<String, dynamic>>.from(rawProfiles);

    final profilesById = <String, Map<String, dynamic>>{
      for (final profile in profiles)
        if (profile['id'] != null) profile['id'].toString(): profile,
    };

    final likeCountByFeature = <String, int>{};
    final likedByMe = <String>{};

    for (final like in likes) {
      final featureId = like['feature_id']?.toString();

      if (featureId == null) {
        continue;
      }

      likeCountByFeature[featureId] = (likeCountByFeature[featureId] ?? 0) + 1;

      if (user != null && like['user_id']?.toString() == user.id) {
        likedByMe.add(featureId);
      }
    }

    final commentsByFeature = <String, List<Map<String, dynamic>>>{};

    for (final comment in comments) {
      final featureId = comment['feature_id']?.toString();

      if (featureId == null) {
        continue;
      }

      commentsByFeature.putIfAbsent(featureId, () => []).add(comment);
    }

    return suggestions.map((suggestion) {
      final featureId = suggestion['id']?.toString() ?? '';
      final suggestionUserId = suggestion['user_id']?.toString();
      final profile = suggestionUserId == null
          ? null
          : profilesById[suggestionUserId];

      final suggestionAllowsAttribution =
          suggestion['public_attribution'] != false;
      final profileAllowsAttribution =
          profile?['privacy_feature_suggestion_attribution'] != false;
      final showAttribution =
          suggestionUserId != null &&
          suggestionAllowsAttribution &&
          profileAllowsAttribution;

      return <String, dynamic>{
        ...suggestion,
        'like_count': likeCountByFeature[featureId] ?? 0,
        'liked_by_me': likedByMe.contains(featureId),
        'developer_updates':
            commentsByFeature[featureId] ?? <Map<String, dynamic>>[],
        'show_attribution': showAttribution,
        'suggested_by_user_id': suggestionUserId,
        'suggested_by_display_name': showAttribution && profile != null
            ? profile['display_name']
            : null,
        'suggested_by_username': showAttribution && profile != null
            ? profile['username']
            : null,
        'suggested_by_avatar_url': showAttribution && profile != null
            ? profile['avatar_url']
            : null,
      };
    }).toList();
  }

  Future<bool> toggleLike(String featureId) async {
    final result = await client.rpc(
      'toggle_feature_suggestion_like',
      params: {'p_feature_id': featureId},
    );

    return result == true;
  }

  Future<void> setStatus({
    required String featureId,
    required String status,
    String? developerNote,
  }) async {
    await client.rpc(
      'set_feature_suggestion_status',
      params: {
        'p_feature_id': featureId,
        'p_status': status,
        'p_note': developerNote?.trim(),
      },
    );
  }

  Future<void> ignoreSuggestion(String featureId) async {
    await client.rpc(
      'ignore_feature_suggestion',
      params: {'p_feature_id': featureId},
    );
  }

  Future<void> addDeveloperUpdate({
    required String featureId,
    required String body,
  }) async {
    await client.rpc(
      'add_feature_suggestion_update',
      params: {'p_feature_id': featureId, 'p_body': body.trim()},
    );
  }
}
