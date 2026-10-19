import 'package:flutter/material.dart';
import 'theme/chiplux_palette.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/feature_suggestion_service.dart';
import 'services/profile_service.dart';

const Color _adminBackground = chipluxBackground;
const Color _adminSurface = chipluxSurface;
const Color _adminSurfaceLight = chipluxSurfaceLight;
const Color _adminCyan = chipluxGold;
const Color _adminViolet = chipluxBrightGold;
const Color _adminPurple = chipluxAmber;
const Color _adminGreen = Color(0xFF65E6A5);
const Color _adminRed = Color(0xFFFF6B8A);

/// Only feature suggestions belong on this moderation screen.
/// Bug, user and comment reports are retained in their database tables,
/// with email notifications handled by the Supabase report-mail webhook.
class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> {
  final client = Supabase.instance.client;
  final featureService = FeatureSuggestionService.instance;
  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> featureSuggestions = [];
  final Map<String, Map<String, dynamic>> profiles = {};
  String suggestionFilter = 'pending';

  bool get _allowed => ProfileService.instance.isDeveloper;

  @override
  void initState() {
    super.initState();
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
      // Do not query bug_reports, user_reports, comment_reports or
      // music_album_comment_reports from this page.
      final raw = await client.from('feature_suggestions')
          .select().order('created_at', ascending: false);
      final suggestions = List<Map<String, dynamic>>.from(raw);
      final userIds = suggestions.map((row) => row['user_id']?.toString())
          .whereType<String>().toSet().toList();
      final loadedProfiles = <Map<String, dynamic>>[];
      if (userIds.isNotEmpty) {
        final cards = await client.rpc(
          'get_safe_profile_cards', params: {'p_user_ids': userIds},
        );
        if (cards is List) {
          loadedProfiles.addAll(cards.whereType<Map>().map(
            (card) => Map<String, dynamic>.from(card),
          ));
        }
      }
      if (!mounted) return;
      setState(() {
        featureSuggestions = suggestions;
        profiles
          ..clear()
          ..addEntries(loadedProfiles.where((p) => p['id'] != null)
              .map((p) => MapEntry(p['id'].toString(), p)));
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Could not load suggestions: $e';
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
                const Text(
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
                    hintText: status == 'rejected'
                        ? 'Why is this suggestion being rejected?'
                        : 'Optional Chiplux update...',
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
                    child: Text(
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
          content: Text('Could not update feature suggestion: $e'),
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
          content: const Text(
            'This suggestion will not appear on the Feature Board and will be permanently deleted. The user will still keep their 30-day submission cooldown.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
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
          content: Text('Could not ignore suggestion: $e'),
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
                const Text(
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
                    hintText: 'Write a progress update...',
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
                    label: const Text('Publish Update'),
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
          content: Text('Feature Board update published.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _adminSurfaceLight,
          content: Text('Could not publish update: $e'),
        ),
      );
    }
  }

  Widget _suggestion(Map<String, dynamic> suggestion) {
    final status = suggestion['status']?.toString() ?? 'pending';
    final title = suggestion['title']?.toString() ?? 'Untitled suggestion';
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
                const Text(
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
                  child: Text(
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
        label: Text(text),
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
                label: const Text('Ignore'),
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
              label: const Text('Add Developer Update'),
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

  Widget _suggestionsTab() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(errorMessage!, textAlign: TextAlign.center),
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
                        child: Text(
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
          color: Colors.transparent,
          border: Border.all(
            color: _adminCyan.withValues(alpha: selected ? .95 : .42),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _adminCyan,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
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
      child: Text(
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
        return chipluxTextGradient.createShader(bounds);
      },
      child: Text(
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
        return chipluxTextGradient.createShader(bounds);
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
  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      return const Scaffold(
        backgroundColor: _adminBackground,
        body: Center(child: Text('Developer access required.')),
      );
    }

    return Scaffold(
      backgroundColor: _adminBackground,
      appBar: AppBar(backgroundColor: _adminBackground, elevation: 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _gradientTitle('Suggestion Moderation'),
                const SizedBox(height: 7),
                const Text(
                  'Review community feature requests, publish decisions and post developer updates.',
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          Expanded(child: _suggestionsTab()),
        ],
      ),
    );
  }
}
