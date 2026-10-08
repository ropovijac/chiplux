import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/profile_service.dart';

const Color _adminBackground = Color(0xFF07111C);
const Color _adminSurface = Color(0xFF111D2A);
const Color _adminSurfaceLight = Color(0xFF162536);
const Color _adminCyan = Color(0xFF43E8FF);
const Color _adminViolet = Color(0xFF8B7CFF);
const Color _adminPurple = Color(0xFFD65CFF);

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage>
    with SingleTickerProviderStateMixin {
  final client = Supabase.instance.client;

  late final TabController _tabs;

  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> userReports = [];
  List<Map<String, dynamic>> commentReports = [];
  List<Map<String, dynamic>> bugReports = [];

  final Map<String, Map<String, dynamic>> profiles = {};
  final Map<String, Map<String, dynamic>> comments = {};

  bool get _allowed => ProfileService.instance.isDeveloper;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    if (!_allowed) {
      if (mounted) {
        setState(() {
          loading = false;
          errorMessage = 'Developer access required.';
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
      ]);

      final users = List<Map<String, dynamic>>.from(raw[0] as List);
      final commentRows = List<Map<String, dynamic>>.from(raw[1] as List);

      // Keep resolved bug reports in the database for history/audit,
      // but remove them from the active moderation queue.
      final bugs = List<Map<String, dynamic>>.from(raw[2] as List)
          .where((row) => row['status']?.toString() != 'resolved')
          .toList();

      final profileIds = <String>{};

      for (final report in users) {
        final reporterId = report['reporter_id']?.toString();
        final reportedId = report['reported_user_id']?.toString();

        if (reporterId != null) {
          profileIds.add(reporterId);
        }

        if (reportedId != null) {
          profileIds.add(reportedId);
        }
      }

      for (final report in bugs) {
        final userId = report['user_id']?.toString();

        if (userId != null) {
          profileIds.add(userId);
        }
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

        loadedComments.addAll(
          List<Map<String, dynamic>>.from(rows),
        );

        for (final comment in loadedComments) {
          final userId = comment['user_id']?.toString();

          if (userId != null) {
            profileIds.add(userId);
          }
        }
      }

      final loadedProfiles = <Map<String, dynamic>>[];

      if (profileIds.isNotEmpty) {
        final rows = await client
            .from('profiles')
            .select(
              'id, display_name, username, avatar_url',
            )
            .inFilter('id', profileIds.toList());

        loadedProfiles.addAll(
          List<Map<String, dynamic>>.from(rows),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        userReports = users;
        commentReports = commentRows;
        bugReports = bugs;

        profiles
          ..clear()
          ..addEntries(
            loadedProfiles
                .where((profile) => profile['id'] != null)
                .map(
                  (profile) => MapEntry(
                    profile['id'].toString(),
                    profile,
                  ),
                ),
          );

        comments
          ..clear()
          ..addEntries(
            loadedComments
                .where((comment) => comment['id'] != null)
                .map(
                  (comment) => MapEntry(
                    comment['id'].toString(),
                    comment,
                  ),
                ),
          );

        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          errorMessage =
              'Could not load moderation reports: $e';
        });
      }
    }
  }

  String _who(String? id) {
    if (id == null) {
      return 'Unknown user';
    }

    final profile = profiles[id];

    if (profile == null) {
      return id;
    }

    final displayName =
        profile['display_name']?.toString().trim() ?? '';

    final username =
        profile['username']?.toString().trim() ?? '';

    if (displayName.isNotEmpty && username.isNotEmpty) {
      return '$displayName (@$username)';
    }

    if (username.isNotEmpty) {
      return '@$username';
    }

    if (displayName.isNotEmpty) {
      return displayName;
    }

    return id;
  }

  Future<void> _status(
    String table,
    Object id,
    String value,
  ) async {
    try {
      await client
          .from(table)
          .update({'status': value})
          .eq('id', id);

      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update report: $e',
          ),
        ),
      );
    }
  }

  Future<void> _resolveBug(
    Map<String, dynamic> report,
  ) async {
    final id = report['id'];

    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _adminSurface,
          title: const Text(
            'Resolve this bug?',
          ),
          content: const Text(
            'This will mark the bug as solved and remove it '
            'from the active Bugs queue.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.check_circle_outline_rounded,
              ),
              label: const Text('Resolve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _status(
      'bug_reports',
      id,
      'resolved',
    );
  }

  Future<void> _deleteComment(
    Map<String, dynamic> report,
  ) async {
    final id = report['comment_id']?.toString();

    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _adminSurface,
          title: const Text(
            'Delete reported comment?',
          ),
          content: const Text(
            'This permanently removes the comment.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await client
        .from('media_comments')
        .delete()
        .eq('id', id);

    await _load();
  }

  Widget _actions(
    String table,
    Object id, {
    VoidCallback? deleteComment,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () {
            _status(
              table,
              id,
              'reviewing',
            );
          },
          child: const Text('Reviewing'),
        ),
        OutlinedButton(
          onPressed: () {
            _status(
              table,
              id,
              'dismissed',
            );
          },
          child: const Text('Dismiss'),
        ),
        FilledButton(
          onPressed: () {
            _status(
              table,
              id,
              'resolved',
            );
          },
          child: const Text('Resolve'),
        ),
        if (deleteComment != null)
          TextButton.icon(
            onPressed: deleteComment,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            label: const Text(
              'Delete comment',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _bugActions(
    Map<String, dynamic> report,
  ) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          _resolveBug(report);
        },
        icon: const Icon(
          Icons.check_circle_outline_rounded,
        ),
        label: const Text('Resolve'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: 13,
          ),
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
      margin: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        8,
      ),
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
                Text(
                  header,
                  style: const TextStyle(
                    color: _adminCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _adminCyan.withValues(
                      alpha: .09,
                    ),
                    borderRadius: BorderRadius.circular(
                      99,
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: _adminCyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _adminSurfaceLight,
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: Text(
                body,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            actions,
          ],
        ),
      ),
    );
  }

  Widget _user(
    Map<String, dynamic> report,
  ) {
    final id = report['id'];

    final status =
        report['status']?.toString() ?? 'open';

    final reason =
        report['reason']?.toString() ?? 'No reason';

    final details =
        report['details']?.toString().trim() ?? '';

    return _card(
      'USER REPORT',
      status,
      _who(
        report['reported_user_id']?.toString(),
      ),
      'Reported by ${_who(report['reporter_id']?.toString())}',
      details.isEmpty
          ? reason
          : '$reason\n\n$details',
      _actions(
        'user_reports',
        id,
      ),
    );
  }

  Widget _comment(
    Map<String, dynamic> report,
  ) {
    final id = report['id'];

    final status =
        report['status']?.toString() ?? 'open';

    final commentId =
        report['comment_id']?.toString();

    final comment = commentId == null
        ? null
        : comments[commentId];

    final type =
        report['report_type']?.toString() ??
            'comment';

    return _card(
      type == 'spoiler'
          ? 'SPOILER REPORT'
          : 'COMMENT REPORT',
      status,
      _who(
        comment?['user_id']?.toString(),
      ),
      'Reported by ${_who(report['reporter_id']?.toString())}',
      comment?['body']?.toString() ??
          'Comment no longer exists.',
      _actions(
        'comment_reports',
        id,
        deleteComment: commentId == null
            ? null
            : () {
                _deleteComment(report);
              },
      ),
    );
  }

  Widget _bug(
    Map<String, dynamic> report,
  ) {
    return _card(
      'BUG REPORT',
      report['status']?.toString() ??
          'open',
      _who(
        report['user_id']?.toString(),
      ),
      report['created_at']?.toString() ??
          '',
      report['description']?.toString() ??
          '',
      _bugActions(report),
    );
  }

  Widget _list(
    List<Map<String, dynamic>> rows,
    Widget Function(Map<String, dynamic>) builder,
  ) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.inbox_outlined,
              color: Colors.white24,
              size: 42,
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No reports.',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: 30,
        ),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          return builder(rows[index]);
        },
      ),
    );
  }

  Widget _gradientTitle(
    String text,
  ) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            _adminCyan,
            _adminViolet,
            _adminPurple,
          ],
        ).createShader(bounds);
      },
      child: Text(
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
        body: Center(
          child: Text(
            'Developer access required.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _adminBackground,

      // Back arrow only. The page title lives in the content area.
      appBar: AppBar(
        backgroundColor: _adminBackground,
        elevation: 0,
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _gradientTitle(
                  'Admin Moderation',
                ),
                const SizedBox(height: 5),
                const Text(
                  'Review reports, remove harmful content and resolve bug reports.',
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
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: 0.06,
                      ),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    dividerColor: Colors.transparent,
                    indicatorSize:
                        TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(12),
                      gradient:
                          const LinearGradient(
                        colors: [
                          _adminCyan,
                          _adminViolet,
                          _adminPurple,
                        ],
                      ),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor:
                        Colors.white54,
                    labelStyle:
                        const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                        ),
                        text: 'Users',
                      ),
                      Tab(
                        icon: Icon(
                          Icons.forum_outlined,
                          size: 18,
                        ),
                        text: 'Comments',
                      ),
                      Tab(
                        icon: Icon(
                          Icons.bug_report_outlined,
                          size: 18,
                        ),
                        text: 'Bugs',
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
                _list(
                  userReports,
                  _user,
                ),
                _list(
                  commentReports,
                  _comment,
                ),
                _list(
                  bugReports,
                  _bug,
                ),
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
