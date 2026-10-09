import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'l10n/ui_translations.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/feature_suggestion_service.dart';
import 'services/profile_service.dart';

const Color _adminBackground = Color(0xFF07111C);
const Color _adminSurface = Color(0xFF111D2A);
const Color _adminSurfaceLight = Color(0xFF162536);
const Color _adminCyan = Color(0xFF43E8FF);
const Color _adminViolet = Color(0xFF8B7CFF);
const Color _adminPurple = Color(0xFFD65CFF);
const Color _adminGreen = Color(0xFF65E6A5);
const Color _adminRed = Color(0xFFFF6B8A);

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage>
    with SingleTickerProviderStateMixin {
  final client = Supabase.instance.client;
  final featureService = FeatureSuggestionService.instance;

  late final TabController _tabs;

  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> userReports = [];
  List<Map<String, dynamic>> commentReports = [];
  List<Map<String, dynamic>> bugReports = [];
  List<Map<String, dynamic>> featureSuggestions = [];

  final Map<String, Map<String, dynamic>> profiles = {};
  final Map<String, Map<String, dynamic>> comments = {};

  String suggestionFilter = 'pending';

  bool get _allowed => ProfileService.instance.isDeveloper;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  Future<void> _load() async {
    if (!_allowed) {
      if (mounted) {
        setState(() {
          loading = false;
          errorMessage = AppLocalizations.of(context).developerAccessRequired;
        });
      }
      return;
    }

    try {
      final raw = await Future.wait([
        client
            .from('user_reports')
            .select()
            .order('created_at', ascending: false),
        client
            .from('comment_reports')
            .select()
            .order('created_at', ascending: false),
        client
            .from('bug_reports')
            .select()
            .order('created_at', ascending: false),
        client
            .from('feature_suggestions')
            .select()
            .order('created_at', ascending: false),
      ]);

      final users = List<Map<String, dynamic>>.from(raw[0] as List);
      final commentRows = List<Map<String, dynamic>>.from(raw[1] as List);

      final bugs = List<Map<String, dynamic>>.from(raw[2] as List)
          .where((row) => row['status']?.toString() != 'resolved')
          .toList();

      final suggestions = List<Map<String, dynamic>>.from(raw[3] as List);

      final profileIds = <String>{};

      for (final report in users) {
        final reporterId = report['reporter_id']?.toString();
        final reportedId = report['reported_user_id']?.toString();

        if (reporterId != null) profileIds.add(reporterId);
        if (reportedId != null) profileIds.add(reportedId);
      }

      for (final report in bugs) {
        final userId = report['user_id']?.toString();
        if (userId != null) profileIds.add(userId);
      }

      for (final suggestion in suggestions) {
        final userId = suggestion['user_id']?.toString();
        if (userId != null) profileIds.add(userId);
      }

      final commentIds = commentRows
          .map((report) => report['comment_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final loadedComments = <Map<String, dynamic>>[];

      if (commentIds.isNotEmpty) {
        final rows = await client
            .from('media_comments')
            .select(
              'id, user_id, body, media_type, tmdb_id, '
              'season_number, episode_number',
            )
            .inFilter('id', commentIds);

        loadedComments.addAll(List<Map<String, dynamic>>.from(rows));

        for (final comment in loadedComments) {
          final userId = comment['user_id']?.toString();
          if (userId != null) profileIds.add(userId);
        }
      }

      final loadedProfiles = <Map<String, dynamic>>[];

      if (profileIds.isNotEmpty) {
        final rows = await client
            .from('profiles')
            .select('id, display_name, username, avatar_url')
            .inFilter('id', profileIds.toList());

        loadedProfiles.addAll(List<Map<String, dynamic>>.from(rows));
      }

      if (!mounted) return;

      setState(() {
        userReports = users;
        commentReports = commentRows;
        bugReports = bugs;
        featureSuggestions = suggestions;

        profiles
          ..clear()
          ..addEntries(
            loadedProfiles
                .where((profile) => profile['id'] != null)
                .map((profile) => MapEntry(profile['id'].toString(), profile)),
          );

        comments
          ..clear()
          ..addEntries(
            loadedComments
                .where((comment) => comment['id'] != null)
                .map((comment) => MapEntry(comment['id'].toString(), comment)),
          );

        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = AppLocalizations.of(context)
            .couldNotLoadModeration(e.toString());
      });
    }
  }

  String _who(String? id) {
    if (id == null) return 'Deleted user';

    final profile = profiles[id];
    if (profile == null) return id;

    final displayName = profile['display_name']?.toString().trim() ?? '';
    final username = profile['username']?.toString().trim() ?? '';

    if (displayName.isNotEmpty && username.isNotEmpty) {
      return '$displayName (@$username)';
    }

    if (username.isNotEmpty) return '@$username';
    if (displayName.isNotEmpty) return displayName;
    return id;
  }

  String _dateLabel(Object? raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.${date.year}. · $hour:$minute';
  }

  Future<void> _status(String table, Object id, String value) async {
    try {
      await client.from(table).update({'status': value}).eq('id', id);
      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _adminSurfaceLight,
          content: UiText('Could not update report: $e'),
        ),
      );
    }
  }

  Future<void> _resolveBug(Map<String, dynamic> report) async {
    final id = report['id'];
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _adminSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: _adminCyan.withValues(alpha: 0.28)),
          ),
          title: _dialogGradientTitle(
            AppLocalizations.of(context).resolveBugQuestion,
          ),
          content: const UiText(
            'This will mark the bug as solved and remove it from the active Bugs queue.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const UiText('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const UiText('Resolve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _status('bug_reports', id, 'resolved');
  }

  Future<void> _deleteComment(Map<String, dynamic> report) async {
    final id = report['comment_id']?.toString();
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _adminSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: _adminRed.withValues(alpha: 0.28)),
          ),
          title: _dialogGradientTitle(
            AppLocalizations.of(context).deleteReportedComment,
          ),
          content: const UiText(
            'This permanently removes the comment.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const UiText('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const UiText(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await client.from('media_comments').delete().eq('id', id);
    await _load();
  }

  Future<void> _setSuggestionStatus(
    Map<String, dynamic> suggestion,
    String status,
  ) async {
    final id = suggestion['id']?.toString();
    if (id == null) return;

    final noteController = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _adminSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogGradientTitle('Set ${_suggestionStatusLabel(status)}'),
                const SizedBox(height: 7),
                const UiText(
                  'You can add an optional developer note. It will appear publicly on the Feature Board.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hint: UiText(
                      status == 'rejected'
                          ? 'Why is this suggestion being rejected?'
                          : 'Optional Chiplux update...',
                    ),
                    filled: true,
                    fillColor: _adminSurfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _adminCyan),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_adminCyan, _adminViolet, _adminPurple],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext, noteController.text.trim());
                    },
                    child: UiText(
                      'Publish as ${_suggestionStatusLabel(status)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    noteController.dispose();

    if (result == null) return;

    try {
      await featureService.setStatus(
        featureId: id,
        status: status,
        developerNote: result.isEmpty ? null : result,
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _adminSurfaceLight,
          content: UiText('Could not update feature suggestion: $e'),
        ),
      );
    }
  }

  Future<void> _ignoreSuggestion(Map<String, dynamic> suggestion) async {
    final id = suggestion['id']?.toString();
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _adminSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          title: _dialogGradientTitle(
            AppLocalizations.of(context).ignoreSuggestionQuestion,
          ),
          content: const UiText(
            'This suggestion will not appear on the Feature Board and will be permanently deleted. The user will still keep their 30-day submission cooldown.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const UiText('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const UiText(
                'Ignore & Delete',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await featureService.ignoreSuggestion(id);
      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _adminSurfaceLight,
          content: UiText('Could not ignore suggestion: $e'),
        ),
      );
    }
  }

  Future<void> _addSuggestionUpdate(Map<String, dynamic> suggestion) async {
    final id = suggestion['id']?.toString();
    if (id == null) return;

    final controller = TextEditingController();

    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _adminSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogGradientTitle('Add Chiplux update'),
                const SizedBox(height: 7),
                const UiText(
                  'Only developer updates can appear below Feature Board posts.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hint: const UiText('Write a progress update...'),
                    filled: true,
                    fillColor: _adminSurfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isNotEmpty) {
                        Navigator.pop(sheetContext, value);
                      }
                    },
                    icon: const Icon(Icons.campaign_rounded),
                    label: const UiText('Publish Update'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (body == null || body.isEmpty) return;

    try {
      await featureService.addDeveloperUpdate(featureId: id, body: body);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _adminSurfaceLight,
          content: UiText('Feature Board update published.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _adminSurfaceLight,
          content: UiText('Could not publish update: $e'),
        ),
      );
    }
  }

  Widget _actions(String table, Object id, {VoidCallback? deleteComment}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => _status(table, id, 'reviewing'),
          child: const UiText('Reviewing'),
        ),
        OutlinedButton(
          onPressed: () => _status(table, id, 'dismissed'),
          child: const UiText('Dismiss'),
        ),
        FilledButton(
          onPressed: () => _status(table, id, 'resolved'),
          child: const UiText('Resolve'),
        ),
        if (deleteComment != null)
          TextButton.icon(
            onPressed: deleteComment,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            label: const UiText(
              'Delete comment',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }

  Widget _bugActions(Map<String, dynamic> report) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _resolveBug(report),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const UiText('Resolve'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          backgroundColor: _adminCyan,
          foregroundColor: _adminBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _card(
    String header,
    String status,
    String title,
    String subtitle,
    String body,
    Widget actions,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _adminCyan.withValues(alpha: 0.42),
            _adminViolet.withValues(alpha: 0.24),
            _adminPurple.withValues(alpha: 0.30),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _adminSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UiText(
                  header,
                  style: const TextStyle(
                    color: _adminCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                _statusPill(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _adminSurfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                body,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            actions,
          ],
        ),
      ),
    );
  }

  Widget _user(Map<String, dynamic> report) {
    final id = report['id'];
    final status = report['status']?.toString() ?? 'open';
    final reason = report['reason']?.toString() ?? trUi(context, 'No reason');
    final details = report['details']?.toString().trim() ?? '';

    return _card(
      'USER REPORT',
      status,
      _who(report['reported_user_id']?.toString()),
      'Reported by ${_who(report['reporter_id']?.toString())}',
      details.isEmpty ? reason : '$reason\n\n$details',
      _actions('user_reports', id),
    );
  }

  Widget _comment(Map<String, dynamic> report) {
    final id = report['id'];
    final status = report['status']?.toString() ?? 'open';
    final commentId = report['comment_id']?.toString();
    final comment = commentId == null ? null : comments[commentId];
    final type = report['report_type']?.toString() ?? 'comment';

    return _card(
      type == 'spoiler' ? 'SPOILER REPORT' : 'COMMENT REPORT',
      status,
      _who(comment?['user_id']?.toString()),
      'Reported by ${_who(report['reporter_id']?.toString())}',
      comment?['body']?.toString() ??
          trUi(context, 'Comment no longer exists.'),
      _actions(
        'comment_reports',
        id,
        deleteComment: commentId == null ? null : () => _deleteComment(report),
      ),
    );
  }

  Widget _bug(Map<String, dynamic> report) {
    return _card(
      'BUG REPORT',
      report['status']?.toString() ?? 'open',
      _who(report['user_id']?.toString()),
      _dateLabel(report['created_at']),
      report['description']?.toString() ?? '',
      _bugActions(report),
    );
  }

  Widget _suggestion(Map<String, dynamic> suggestion) {
    final status = suggestion['status']?.toString() ?? 'pending';
    final title =
        suggestion['title']?.toString() ?? trUi(context, 'Untitled suggestion');
    final description = suggestion['description']?.toString() ?? '';
    final requestedAttribution = suggestion['public_attribution'] != false;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _statusColor(status).withValues(alpha: 0.52),
            _adminViolet.withValues(alpha: 0.24),
            _adminPurple.withValues(alpha: 0.28),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _adminSurface,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: _adminCyan,
                  size: 19,
                ),
                const SizedBox(width: 8),
                const UiText(
                  'FEATURE SUGGESTION',
                  style: TextStyle(
                    color: _adminCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                _statusPill(status),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              '${_who(suggestion['user_id']?.toString())} · ${_dateLabel(suggestion['created_at'])}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _adminSurfaceLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                description,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  requestedAttribution
                      ? Icons.person_pin_circle_outlined
                      : Icons.person_off_outlined,
                  color: requestedAttribution ? _adminViolet : Colors.white38,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: UiText(
                    requestedAttribution
                        ? 'User requested public credit if published.'
                        : 'Publish without user attribution.',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _suggestionActions(suggestion),
          ],
        ),
      ),
    );
  }

  Widget _suggestionActions(Map<String, dynamic> suggestion) {
    final status = suggestion['status']?.toString() ?? 'pending';

    Widget stateButton(String value, String text, IconData icon) {
      final current = status == value;
      final color = _statusColor(value);

      return OutlinedButton.icon(
        onPressed: current
            ? null
            : () => _setSuggestionStatus(suggestion, value),
        icon: Icon(icon, size: 17),
        label: UiText(text),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.55)),
          disabledForegroundColor: Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            stateButton(
              'in_progress',
              'In Progress',
              Icons.construction_rounded,
            ),
            stateButton('implemented', 'Implemented', Icons.task_alt_rounded),
            stateButton('rejected', 'Rejected', Icons.close_rounded),
            if (status == 'pending')
              TextButton.icon(
                onPressed: () => _ignoreSuggestion(suggestion),
                icon: const Icon(Icons.visibility_off_outlined, size: 17),
                label: const UiText('Ignore'),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
              ),
          ],
        ),
        if (status != 'pending') ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _addSuggestionUpdate(suggestion),
              icon: const Icon(Icons.campaign_outlined),
              label: const UiText('Add Developer Update'),
              style: FilledButton.styleFrom(
                backgroundColor: _adminViolet.withValues(alpha: 0.15),
                foregroundColor: _adminViolet,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _list(
    List<Map<String, dynamic>> rows,
    Widget Function(Map<String, dynamic>) builder,
  ) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: UiText(errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(
              child: UiText(
                'No reports.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        itemBuilder: (context, index) => builder(rows[index]),
      ),
    );
  }

  Widget _suggestionsTab() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: UiText(errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    final filtered = featureSuggestions.where((suggestion) {
      return suggestion['status']?.toString() == suggestionFilter;
    }).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: [
              _filterPill('pending', 'Pending'),
              const SizedBox(width: 8),
              _filterPill('in_progress', 'In Progress'),
              const SizedBox(width: 8),
              _filterPill('implemented', 'Implemented'),
              const SizedBox(width: 8),
              _filterPill('rejected', 'Rejected'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 135),
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Colors.white.withValues(alpha: 0.18),
                        size: 42,
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: UiText(
                          'No ${_suggestionStatusLabel(suggestionFilter).toLowerCase()} suggestions.',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _suggestion(filtered[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filterPill(String value, String label) {
    final selected = suggestionFilter == value;
    final count = featureSuggestions.where((item) {
      return item['status']?.toString() == value;
    }).length;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          suggestionFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  colors: [_adminCyan, _adminViolet, _adminPurple],
                )
              : null,
          color: selected ? null : _adminSurface,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiText(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: selected ? 0.20 : 0.16),
                borderRadius: BorderRadius.circular(99),
              ),
              child: UiText(
                '$count',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: UiText(
        _suggestionStatusLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'implemented':
        return _adminGreen;
      case 'rejected':
        return _adminRed;
      case 'in_progress':
        return _adminViolet;
      case 'pending':
      default:
        return _adminCyan;
    }
  }

  String _suggestionStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'implemented':
        return 'Implemented';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  Widget _dialogGradientTitle(String text) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [_adminCyan, _adminViolet, _adminPurple],
        ).createShader(bounds);
      },
      child: UiText(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _gradientTitle(String text) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [_adminCyan, _adminViolet, _adminPurple],
        ).createShader(bounds);
      },
      child: UiText(
        text,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      return const Scaffold(
        backgroundColor: _adminBackground,
        body: Center(child: UiText('Developer access required.')),
      );
    }

    return Scaffold(
      backgroundColor: _adminBackground,
      appBar: AppBar(backgroundColor: _adminBackground, elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _gradientTitle('Admin Moderation'),
                const SizedBox(height: 5),
                const UiText(
                  'Review reports, resolve bugs and decide which community feature ideas become public.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _adminSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [_adminCyan, _adminViolet, _adminPurple],
                      ),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.person_outline_rounded, size: 18),
                        child: UiText('Users'),
                      ),
                      Tab(
                        icon: Icon(Icons.forum_outlined, size: 18),
                        child: UiText('Comments'),
                      ),
                      Tab(
                        icon: Icon(Icons.bug_report_outlined, size: 18),
                        child: UiText('Bugs'),
                      ),
                      Tab(
                        icon: Icon(Icons.lightbulb_outline_rounded, size: 18),
                        child: UiText('Suggestions'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _list(userReports, _user),
                _list(commentReports, _comment),
                _list(bugReports, _bug),
                _suggestionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
}
