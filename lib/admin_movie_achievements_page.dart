import 'package:flutter/material.dart';
import 'theme/chiplux_palette.dart';

import 'services/custom_movie_achievement_service.dart';
import 'services/profile_service.dart';
import 'services/tmdb_service.dart';

const _bg = chipluxBackground;
const _surface = chipluxSurface;
const _cyan = chipluxGold;
const _violet = chipluxBrightGold;

/// Admin-only manager for published and unpublished movie-watch achievements.
/// Authorization is also enforced in Supabase RLS policies.
class AdminMovieAchievementsPage extends StatefulWidget {
  const AdminMovieAchievementsPage({super.key});

  @override
  State<AdminMovieAchievementsPage> createState() => _AdminMovieAchievementsPageState();
}

class _AdminMovieAchievementsPageState extends State<AdminMovieAchievementsPage> {
  bool _refreshing = false;
  bool _mutating = false;
  String? _error;

  Future<void> _reload() async {
    setState(() { _refreshing = true; _error = null; });
    try {
      await CustomMovieAchievementService.instance.load();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<bool> _confirm(String title, String explanation, String action) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text(title),
        content: Text(explanation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action, style: const TextStyle(color: _cyan))),
        ],
      ),
    ) ?? false;
  }

  Future<void> _edit(CustomMovieAchievement achievement) async {
    final updated = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => _MovieAchievementEditorPage(original: achievement),
    ));
    if (updated == true && mounted) await _reload();
  }

  Future<void> _setPublished(CustomMovieAchievement achievement) async {
    if (_mutating) return;
    final willPublish = !achievement.isActive;
    if (!await _confirm(
  willPublish ? 'Republish achievement?' : 'Unpublish achievement?',
  willPublish
      ? 'Restore this achievement for everyone and recalculate completion from their current watched movies?'
      : 'Hide this achievement from users. Their records are kept, but its title and achievement count will be unavailable while it is unpublished.',
  willPublish ? 'Republish' : 'Unpublish',
)) {
  return;
}
    if (!mounted) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await CustomMovieAchievementService.instance.setPublished(achievement, willPublish);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not update publication: $error');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(CustomMovieAchievement achievement) async {
    if (_mutating) return;
    if (!await _confirm(
  'Permanently delete ${achievement.name}?',
  'This cannot be undone. The achievement is removed for everyone, all its unlock records are deleted, and anyone wearing its title will lose it. This also changes achievement and Medal Collection totals.',
  'Delete permanently',
)) {
  return;
}
    if (!mounted) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await CustomMovieAchievementService.instance.deleteAchievement(achievement);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not delete achievement: $error');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ProfileService.instance.isDeveloper) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: Text('Only Chiplux admins can manage achievements.')),
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Movie Achievements'),
        backgroundColor: _bg,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: (_refreshing || _mutating) ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cyan,
        foregroundColor: _bg,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create achievement'),
        onPressed: (_refreshing || _mutating) ? null : () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const _MovieAchievementEditorPage()),
          );
          if (created == true && mounted) await _reload();
        },
      ),
      body: AnimatedBuilder(
        animation: CustomMovieAchievementService.instance,
        builder: (context, _) {
          final service = CustomMovieAchievementService.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              const Text('Manage · Watch These Movies', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Create or edit one-tier achievements for everyone. Changes to required movies recalculate completion automatically. '
                'The achievement is counted in the overall achievement total and Medal Collection.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              if (_refreshing) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 20),
              if (service.definitions.isEmpty)
                const Card(color: _surface, child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No custom achievements yet. Tap Create achievement to add the first one.'),
                )),
              for (final achievement in service.definitions) ...[
                Card(
                  color: _surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(achievement.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 5),
                        Text(achievement.description, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 5),
                        if (!achievement.isActive) ...[
                          const Text('UNPUBLISHED · Hidden from users',
                              style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                        ],
                        Text('REWARD · Title: ${achievement.rewardTitle}', style: const TextStyle(color: _cyan)),
                        const SizedBox(height: 5),
                        Text('Required movies: ${achievement.movieIds.length}', style: const TextStyle(color: Colors.white54)),
                        const SizedBox(height: 7),
                        for (final id in achievement.movieIds)
                          Text('• ${achievement.movieTitles[id] ?? 'TMDB #$id'}',
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton.icon(
                            onPressed: _mutating ? null : () => _edit(achievement),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _mutating ? null : () => _setPublished(achievement),
                            icon: Icon(achievement.isActive
                                ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                            label: Text(achievement.isActive ? 'Unpublish' : 'Republish'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _mutating ? null : () => _delete(achievement),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18,
                                color: Colors.redAccent),
                            label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MovieAchievementEditorPage extends StatefulWidget {
  final CustomMovieAchievement? original;
  const _MovieAchievementEditorPage({this.original});

  @override
  State<_MovieAchievementEditorPage> createState() => _MovieAchievementEditorPageState();
}

class _MovieAchievementEditorPageState extends State<_MovieAchievementEditorPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _reward = TextEditingController();
  final _query = TextEditingController();
  final _required = <int, String>{};
  List<Map<String, dynamic>> _results = const [];
  bool _searching = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final original = widget.original;
    if (original != null) {
      _name.text = original.name;
      _description.text = original.description;
      _reward.text = original.rewardTitle;
      for (final id in original.movieIds) {
        _required[id] = original.movieTitles[id] ?? 'TMDB #$id';
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _reward.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searching || _query.text.trim().length < 2) return;
    setState(() { _searching = true; _results = const []; _error = null; });
    try {
      final results = await TmdbService().search(_query.text.trim());
      if (!mounted) return;
      setState(() {
        _results = results.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) => row['media_type'] == 'movie' && row['id'] is num)
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Movie search failed: $error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty || _description.text.trim().isEmpty ||
        _reward.text.trim().isEmpty || _required.isEmpty) {
      setState(() => _error = 'Enter all three text fields and add at least one movie.');
      return;
    }
    final original = widget.original;
    if (original != null &&
        (original.movieIds.toSet().difference(_required.keys.toSet()).isNotEmpty ||
         _required.keys.toSet().difference(original.movieIds.toSet()).isNotEmpty)) {
      final confirmed = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _surface,
          title: const Text('Recalculate all users?'),
          content: const Text('Changing required movies takes effect immediately. '
              'Users missing a newly required movie lose the achievement and its Profile Title until they complete it again. '
              'Achievement totals and Medal Collection progress will change.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save and recalculate')),
          ],
        ),
      ) ?? false;
      if (!confirmed || !mounted) return;
    }
    if (!mounted) return;
    setState(() { _saving = true; _error = null; });
    try {
      if (original == null) {
        await CustomMovieAchievementService.instance.create(
          name: _name.text, description: _description.text,
          rewardTitle: _reward.text, requiredMovies: _required,
        );
      } else {
        await CustomMovieAchievementService.instance.updateAchievement(
          achievement: original,
          name: _name.text, description: _description.text,
          rewardTitle: _reward.text, requiredMovies: _required,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save achievement: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, title: Text(widget.original == null ? 'Create movie achievement' : 'Edit movie achievement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const Text('Achievement details', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Achievement name',
              hintText: 'Webslinger', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 500,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description',
              hintText: 'Watch all Spider-Man movies.', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reward,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Profile Title reward',
              hintText: 'Your Friendly Neighbourhood', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          const Text('Required movies', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Search TMDB and select movies. Every selected movie becomes required immediately. A movie counts when marked Watched / Completed in the Library.',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: _query,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: 'Search TMDB movies', hintText: 'Spider-Man',
                border: OutlineInputBorder(), prefixIcon: Icon(Icons.search_rounded)),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Search', onPressed: _searching ? null : _search,
              icon: _searching ? const SizedBox(width: 19, height: 19,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search_rounded)),
          ]),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 285),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12)),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final movie = _results[index];
                  final id = (movie['id'] as num).toInt();
                  final title = movie['title']?.toString() ?? 'Movie #$id';
                  final year = movie['release_date']?.toString() ?? '';
                  final poster = movie['poster_path']?.toString() ?? '';
                  final added = _required.containsKey(id);
                  return ListTile(
                    leading: poster.isEmpty
                        ? const Icon(Icons.movie_outlined)
                        : Image.network('https://image.tmdb.org/t/p/w92$poster',
                            width: 36, height: 54, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.movie_outlined)),
                    title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(year.length >= 4 ? year.substring(0, 4) : ''),
                    trailing: Icon(added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                      color: added ? _cyan : _violet),
                    onTap: () {
                      setState(() => _required[id] = title);
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Selected movies (${_required.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          if (_required.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('No required movies added yet.',
              style: TextStyle(color: Colors.white54))),
          for (final entry in _required.entries)
            Card(color: _surface, child: ListTile(
              leading: const Icon(Icons.movie_rounded, color: _cyan),
              title: Text(entry.value),
              subtitle: Text('TMDB movie #${entry.key}'),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                tooltip: 'Remove movie',
                onPressed: () => setState(() => _required.remove(entry.key)),
              ),
            )),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: _cyan, foregroundColor: _bg,
              minimumSize: const Size.fromHeight(52)),
            icon: _saving ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish_rounded),
            label: Text(_saving ? 'Saving…' : (widget.original == null ? 'Publish achievement' : 'Save changes')),
          ),
        ],
      ),
    );
  }
}
