import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

const _chipluxYellow = Color(0xFFFFD21A);
const _pickerSurface = Color(0xFF10151E);

/// Monochrome icon from an allowlisted, permissively licensed Iconify collection.
/// Unknown IDs, missing assets and offline users fall back to the original
/// Material achievement icon, so historic rewards keep rendering.
class IconifyAchievementIcon extends StatelessWidget {
  final String? iconId;
  final IconData fallback;
  final Color color;
  final double size;

  const IconifyAchievementIcon({
    super.key,
    required this.iconId,
    required this.fallback,
    required this.color,
    required this.size,
  });

  static final RegExp _idPattern =
      RegExp(r'^(lucide|tabler|mdi):[a-z0-9]+(?:-[a-z0-9]+)*$');

  static bool isSupported(String? id) =>
      id != null && id.length <= 120 && _idPattern.hasMatch(id);

  @override
  Widget build(BuildContext context) {
    if (!isSupported(iconId)) {
      return Icon(fallback, color: color, size: size);
    }

    final components = iconId!.split(':');
    final url = Uri.https('api.iconify.design',
        '/${components[0]}/${components[1]}.svg');
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.network(
        url.toString(),
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        placeholderBuilder: (_) => Icon(fallback, color: color, size: size),
        errorBuilder: (_, _, _) => Icon(fallback, color: color, size: size),
      ),
    );
  }
}

/// Returns the selected Iconify name, '' to reset to the built-in icon,
/// or null when dismissed without saving the selection.
Future<String?> showAchievementIconPicker(
  BuildContext context, {
  String? selectedIcon,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AchievementIconPicker(selectedIcon: selectedIcon),
  );
}

class _AchievementIconPicker extends StatefulWidget {
  final String? selectedIcon;
  const _AchievementIconPicker({this.selectedIcon});

  @override
  State<_AchievementIconPicker> createState() => _AchievementIconPickerState();
}

class _AchievementIconPickerState extends State<_AchievementIconPicker> {
  static const _pageSize = 48;
  static const _initial = <String>[
    'lucide:award', 'lucide:clapperboard', 'lucide:film',
    'lucide:star', 'lucide:crown', 'lucide:rocket',
    'lucide:shield', 'lucide:heart', 'lucide:flame',
    'lucide:music', 'lucide:skull', 'lucide:swords',
    'tabler:spider', 'tabler:spider-filled', 'tabler:movie',
    'tabler:trophy', 'tabler:planet', 'tabler:alien',
    'mdi:spider-web', 'mdi:gamepad-variant-outline',
    'mdi:movie-open-star', 'mdi:medal-outline',
    'mdi:robot-outline', 'mdi:lightning-bolt-outline',
  ];

  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  int _requestId = 0;
  String _collection = 'all';
  String? _selected;
  List<String> _icons = _initial;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIcon;
  }

  @override
  void dispose() {
    _requestId++;
    _debounce?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 360), () => _search());
  }

  Future<void> _search({bool more = false}) async {
    final query = _queryController.text.trim();
    final requestId = ++_requestId;
    if (query.length < 2) {
      if (mounted){ setState(() {
        _icons = _initial.where((id) => _collection == 'all' ||
            id.startsWith('$_collection:')).toList();
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
        _error = null;
      });
      return;
    }}
    if (mounted){} setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final start = more ? _icons.length : 0;
      final params = <String, String>{
        'query': query,
        'limit': '$_pageSize',
        'start': '$start',
        if (_collection == 'all') 'prefixes': 'lucide,tabler,mdi',
        if (_collection != 'all') 'prefix': _collection,
      };
      final response = await http.get(
        Uri.https('api.iconify.design', '/search', params),
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw StateError('Icon search is temporarily unavailable (${response.statusCode}).');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (json['icons'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .where(IconifyAchievementIcon.isSupported)
          .toList(growable: false);
      if (!mounted || requestId != _requestId) return;
      final total = (json['total'] as num?)?.toInt() ?? 0;
      setState(() {
        _icons = more ? [..._icons, ...items] : items;
        _hasMore = (start + items.length) < total && items.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = 'Could not search Iconify. Check your connection and retry.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _changeCollection(String collection) {
    if (collection == _collection) return;
    setState(() => _collection = collection);
    _debounce?.cancel();
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .79;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      backgroundColor: _pickerSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _chipluxYellow, width: 1),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Choose achievement icon', style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Search thousands of icons. A selected icon appears on the achievement and its pinned badge.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: _queryController,
                onChanged: _onQueryChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search: spider, cinema, planet...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: _chipluxYellow),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _chipluxYellow)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _chipluxYellow, width: 2)),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (name, value) in const [
                    ('All', 'all'), ('Lucide', 'lucide'),
                    ('Tabler', 'tabler'), ('Material', 'mdi'),
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: _collection == value,
                        onSelected: (_) => _changeCollection(value),
                        backgroundColor: Colors.transparent,
                        selectedColor: _chipluxYellow.withValues(alpha: .13),
                        labelStyle: const TextStyle(color: _chipluxYellow),
                        side: BorderSide(color: _chipluxYellow,
                            width: _collection == value ? 2 : 1),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 8),
              if (_loading) const LinearProgressIndicator(color: _chipluxYellow),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent,
                  fontSize: 12)),
              ),
              Expanded(
                child: _icons.isEmpty && !_loading
                    ? const Center(child: Text('No matching icons. Try another search.',
                        style: TextStyle(color: Colors.white70)))
                    : GridView.builder(
                        controller: _scrollController,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: .85,
                        ),
                        itemCount: _icons.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _icons.length) {
                            return Center(child: IconButton(
                              tooltip: 'Load more icons',
                              onPressed: _loadingMore ? null : () => _search(more: true),
                              icon: _loadingMore
                                  ? const CircularProgressIndicator(strokeWidth: 2,
                                      color: _chipluxYellow)
                                  : const Icon(Icons.add_circle_outline, color: _chipluxYellow),
                            ));
                          }
                          final id = _icons[index];
                          final isSelected = id == _selected;
                          return InkWell(
                            onTap: () => setState(() => _selected = id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected
                                    ? _chipluxYellow.withValues(alpha: .12)
                                    : Colors.white.withValues(alpha: .035),
                                border: Border.all(
                                  color: isSelected ? _chipluxYellow : Colors.white12,
                                  width: isSelected ? 2 : 1),
                              ),
                              padding: const EdgeInsets.all(5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconifyAchievementIcon(
                                    iconId: id,
                                    fallback: Icons.stars_outlined,
                                    color: _chipluxYellow,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(id.split(':').last,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 9,
                                        color: Colors.white70)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Text(_selected == null ? 'Using original achievement icon'
                  : 'Selected: $_selected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  child: const Text('Use default',
                    style: TextStyle(color: Colors.white70)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                    style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _chipluxYellow,
                    foregroundColor: const Color(0xFF10151E)),
                  onPressed: _selected == null ? null
                      : () => Navigator.pop(context, _selected),
                  child: const Text('Use icon'),
                ),
              ]),
              const SizedBox(height: 4),
              const Text('Icon collections: Lucide (ISC), Tabler (MIT), Material Design Icons (Apache-2.0). Internet required.',
                style: TextStyle(fontSize: 10, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}
