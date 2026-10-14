part of 'main.dart';

String _discoverText(BuildContext context, String en, String hr) =>
    Localizations.localeOf(context).languageCode == 'hr' ? hr : en;
String _discoverCategoryLabel(
  BuildContext context,
  DiscoverCategory category,
) => switch (category) {
  DiscoverCategory.movies => _discoverText(context, 'Movies', 'Filmovi'),
  DiscoverCategory.tvShows => _discoverText(context, 'TV Shows', 'Serije'),
  DiscoverCategory.albums => _discoverText(context, 'Albums', 'Albumi'),
  DiscoverCategory.songs => _discoverText(context, 'Songs', 'Pjesme'),
};
String _discoverGenreLabel(BuildContext context, DiscoverGenre genre) {
  const translations = {
    'Alternative': 'Alternativna',
    'Blues': 'Blues',
    'Brazilian': 'Brazilska',
    'Children’s Music': 'Dječja glazba',
    'Christian & Gospel': 'Kršćanska i gospel',
    'Classical': 'Klasična',
    'Comedy': 'Komedija',
    'Country': 'Country',
    'Dance': 'Plesna',
    'Electronic': 'Elektronička',
    'Metal': 'Metal',
    'Singer/Songwriter': 'Kantautorska',
    'Hip-Hop/Rap': 'Hip-hop/Rap',
    'Holiday': 'Blagdanska',
    'Indian': 'Indijska',
    'Instrumental': 'Instrumentalna',
    'Jazz': 'Jazz',
    'J-Pop': 'J-pop',
    'K-Pop': 'K-pop',
    'Latin': 'Latino',
    'New Age': 'New age',
    'Pop': 'Pop',
    'R&B/Soul': 'R&B/Soul',
    'Reggae': 'Reggae',
    'Rock': 'Rock',
    'Soundtrack': 'Filmska glazba',
    'Vocal': 'Vokalna',
    'World': 'Glazba svijeta',
  };
  return _discoverText(
    context,
    genre.name,
    translations[genre.name] ?? genre.name,
  );
}

String _discoverHeading(
  BuildContext context,
  DiscoverMode mode,
  DiscoverCategory category,
  DiscoverGenre? genre,
) {
  final label = genre == null
      ? _discoverText(context, 'General', 'Općenito')
      : _discoverGenreLabel(context, genre);
  return switch (mode) {
    DiscoverMode.trending => _discoverText(
      context,
      'Trending $label',
      'Popularno: $label',
    ),
    DiscoverMode.top100 => 'Top 100 $label',
    DiscoverMode.forYou => _discoverText(
      context,
      "Today's $label For You",
      'Danas: $label za tebe',
    ),
  };
}

String _discoverNormalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f]+'), ' ')
    .trim();

MusicAlbum? _discoverAlbumFromItem(Map<String, dynamic> item) {
  final id = item['id']?.toString() ?? '';
  final title = item['name']?.toString() ?? '';
  final artistId = item['artist_id']?.toString() ?? '';
  final artistName = item['artist_name']?.toString() ?? '';
  if (id.isEmpty || title.isEmpty || artistId.isEmpty || artistName.isEmpty) {
    return null;
  }
  return MusicAlbum(
    id: id,
    title: title,
    artistId: artistId,
    artistName: artistName,
    firstReleaseDate: item['first_release_date']?.toString() ?? '',
    genres: (item['genres'] as List? ?? const [])
        .map((genre) => genre.toString())
        .toList(growable: false),
    artworkUrl: item['cover_url']?.toString(),
  );
}

List<Map<String, dynamic>> _discoverPersonalize(
  DiscoverCategory category,
  List<Map<String, dynamic>> rows,
) {
  final weights = <int, double>{};
  final artistWeights = <String, double>{};
  final seenNames = <String>{};
  final seenIds = <int>{};
  if (DiscoverCatalogService.isMusic(category)) {
    final entries = category == DiscoverCategory.albums
        ? MusicUserDataService.instance.albumEntries
        : MusicUserDataService.instance.trackEntries;
    for (final entry in entries) {
      if (entry.isListened || entry.isDropped) {
        seenNames.add(
          '${_discoverNormalize(entry.title)}:${_discoverNormalize(entry.artistName)}',
        );
      }
      if (!entry.isListened && !entry.isFavorite && entry.rating == null) {
        continue;
      }
      final weight = entry.isFavorite
          ? 4.0
          : entry.rating != null
          ? (entry.rating! - 5).toDouble()
          : 1.0;
      if (category == DiscoverCategory.albums && entry.artistName.isNotEmpty) {
        final artist = _discoverNormalize(entry.artistName);
        artistWeights[artist] = (artistWeights[artist] ?? 0) + weight;
      }
      for (final genre in DiscoverCatalogService.musicGenres) {
        if (entry.genres.any(
          (g) => _discoverNormalize(g) == _discoverNormalize(genre.name),
        )) {
          weights[genre.id] = (weights[genre.id] ?? 0) + weight;
        }
      }
    }
  } else {
    final type = DiscoverCatalogService.mediaType(category);
    for (final item in LibraryService.instance.items.where(
      (i) => i.mediaType == type,
    )) {
      if (item.status == 'completed' ||
          item.status == 'dropped' ||
          (type == 'tv' &&
              LibraryService.instance.watchedCountForShow(item.id) > 0)) {
        seenIds.add(item.id);
      }
      final user = MediaUserDataService.instance.getCached(item.id, type);
      final weight =
          (user.isFavorite ||
              MediaUserDataService.instance.isFavorite(item.id, type))
          ? 4.0
          : user.rating != null
          ? (user.rating! - 5).toDouble()
          : item.status == 'completed'
          ? 1.0
          : 0.0;
      for (final genre in item.genreIds) {
        weights[genre] = (weights[genre] ?? 0) + weight;
      }
    }
  }
  final filtered = rows
      .where(
        (row) => DiscoverCatalogService.isMusic(category)
            ? !seenNames.contains(
                '${_discoverNormalize(row['name']?.toString() ?? '')}:${_discoverNormalize(row['artist_name']?.toString() ?? '')}',
              )
            : !seenIds.contains((row['id'] as num?)?.toInt()),
      )
      .toList();
  double score(Map<String, dynamic> row) {
    final genreAffinity = (row['genre_ids'] as List? ?? []).fold<double>(
      0,
      (sum, g) => sum + (weights[g] ?? 0),
    );
    if (category != DiscoverCategory.albums) return genreAffinity;
    final artistAffinity =
        artistWeights[_discoverNormalize(
          row['artist_name']?.toString() ?? '',
        )] ??
        0;
    final rank = (row['chart_rank'] as num?)?.toInt() ?? 100;
    // Popularity is a small tie-breaker, not a substitute for preferences.
    final popularity = (101 - rank.clamp(1, 100)) / 100.0;
    return genreAffinity * 0.25 + artistAffinity * 0.20 + popularity * 0.10;
  }

  final original = <Map<String, dynamic>, int>{
    for (var i = 0; i < filtered.length; i++) filtered[i]: i,
  };
  filtered.sort((a, b) {
    final difference = score(b).compareTo(score(a));
    return difference != 0 ? difference : original[a]!.compareTo(original[b]!);
  });
  return filtered;
}

List<Map<String, dynamic>> _discoverDailyPick(
  DiscoverCategory category,
  DiscoverGenre? genre,
  List<Map<String, dynamic>> rows,
) {
  if (rows.isEmpty) {
    return [];
  }
  final now = DateTime.now();
  final user = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
  final key =
      '$user:${now.year}-${now.month}-${now.day}:${category.name}:${genre?.id ?? 0}';
  var seed = 2166136261;
  for (final code in key.codeUnits) {
    seed = ((seed ^ code) * 16777619) & 0x7fffffff;
  }
  // Choose from the popular pool after the library's exclusions/preferences.
  final pool = category == DiscoverCategory.albums
      ? rows
      : rows.take(20).toList();
  return [pool[math.Random(seed).nextInt(pool.length)]];
}

class _DiscoverBrowsePage extends StatefulWidget {
  final DiscoverMode mode;
  const _DiscoverBrowsePage({super.key, required this.mode});
  @override
  State<_DiscoverBrowsePage> createState() => _DiscoverBrowsePageState();
}

class _DiscoverBrowsePageState extends State<_DiscoverBrowsePage> {
  DiscoverCategory category = DiscoverCategory.movies;
  late Future<List<DiscoverGenre>> genres;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    genres = DiscoverCatalogService.instance.genres(category);
    unawaited(
      DiscoverCatalogService.instance.preloadCategory(category, widget.mode),
    );
  }

  void select(DiscoverCategory value) {
    if (value == category) {
      return;
    }
    setState(() {
      category = value;
      generation++;
      genres = DiscoverCatalogService.instance.genres(value);
    });
    unawaited(
      DiscoverCatalogService.instance.preloadCategory(value, widget.mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              for (final value in const [
                DiscoverCategory.movies,
                DiscoverCategory.tvShows,
                DiscoverCategory.albums,
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Material(
                      color: category == value
                          ? chipluxViolet.withValues(alpha: .22)
                          : chipluxSurface,
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => select(value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 3,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _discoverCategoryLabel(context, value),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: category == value
                                    ? Colors.white
                                    : Colors.white60,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.mode == DiscoverMode.top100)
          Expanded(child: _ChipluxCategorizedLists(category: category)),
        if (widget.mode == DiscoverMode.forYou)
          Expanded(
            child: _ChipluxDailyRecommendation(
              key: ValueKey('daily-${category.name}'),
              category: category,
            ),
          ),
        if (widget.mode == DiscoverMode.trending)
          Expanded(
            child: FutureBuilder<List<DiscoverGenre>>(
              future: genres,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(
                        () => genres = DiscoverCatalogService.instance.genres(
                          category,
                        ),
                      ),
                      child: Text(
                        _discoverText(
                          context,
                          'Could not load genres. Retry',
                          'Žanrovi nisu učitani. Pokušaj ponovno',
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final definitions = <DiscoverGenre?>[null, ...snapshot.data!];
                final extras =
                    widget.mode == DiscoverMode.top100 &&
                        category == DiscoverCategory.movies
                    ? chipluxTopLists.skip(2).toList()
                    : <ChipluxListDefinition>[];
                return RefreshIndicator(
                  color: chipluxCyan,
                  onRefresh: () async {
                    // Refresh the visible category. Sections reload on demand, avoiding
                    // a burst of requests for every genre and inactive tab.
                    DiscoverCatalogService.instance.invalidate(category);
                    setState(() => generation++);
                  },
                  child: ListView.builder(
                    key: PageStorageKey(
                      'discover-${widget.mode.name}-${category.name}',
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                    itemCount: definitions.length + extras.length,
                    itemBuilder: (context, index) {
                      if (index >= definitions.length) {
                        final definition = extras[index - definitions.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DiscoverRankedCard(
                            category: category,
                            genre: DiscoverGenre(switch (definition.type) {
                              ChipluxTopListType.shortMovies => -1,
                              ChipluxTopListType.superheroMovies => -2,
                              _ => -3,
                            }, definition.title),
                            colorIndex: index,
                            heading: trUi(context, definition.title),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DiscoverTop100Page(definition: definition),
                              ),
                            ),
                          ),
                        );
                      }
                      final genre = definitions[index];
                      if (widget.mode == DiscoverMode.top100) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _DiscoverRankedCard(
                            category: category,
                            genre: genre,
                            colorIndex: index,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _DiscoverRankedPage(
                                  category: category,
                                  genre: genre,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return _DiscoverGenreSection(
                        key: ValueKey(
                          '${category.name}:${widget.mode.name}:${genre?.id}:$generation',
                        ),
                        category: category,
                        mode: widget.mode,
                        genre: genre,
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// Each curated list has a distinct vector glyph; genre lists retain
// the existing Chiplux custom-painted vector icon library.
IconData _chipluxCuratedIcon(int? decade, String? misc) {
  if (decade != null) {
    return switch (decade) {
      1960 => Icons.radio_rounded,
      1970 => Icons.album_rounded,
      1980 => Icons.videocam_rounded,
      1990 => Icons.videogame_asset_rounded,
      2000 => Icons.disc_full_rounded,
      2010 => Icons.headphones_rounded,
      2020 => Icons.auto_awesome_rounded,
      _ => Icons.history_rounded,
    };
  }
  return switch (misc) {
    'Hidden Gems' => Icons.diamond_outlined,
    'Under 90 Minutes' => Icons.timer_outlined,
    'Superhero Movies' => Icons.shield_outlined,
    _ => Icons.auto_awesome_rounded,
  };
}

class _DiscoverRankedCard extends StatelessWidget {
  final DiscoverCategory category;
  final DiscoverGenre? genre;
  final VoidCallback onTap;
  final int colorIndex;
  final String? heading;
  final int? decade;
  final String? misc;
  const _DiscoverRankedCard({
    required this.category,
    this.genre,
    required this.onTap,
    required this.colorIndex,
    this.heading,
    this.decade,
    this.misc,
  });

  @override
  Widget build(BuildContext context) {
    const accents = [
      chipluxCyan,
      chipluxViolet,
      chipluxPurple,
      Color(0xFFFFB84D),
      Color(0xFF43D9C5),
      Color(0xFFFF6C9E),
    ];
    final accent = accents[colorIndex % accents.length];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(accent.withValues(alpha: .34), chipluxSurface),
                Color.alphaBlend(
                  chipluxViolet.withValues(alpha: .12),
                  chipluxSurface,
                ),
                chipluxSurface,
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: .30)),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: .08), blurRadius: 18),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: .40),
                      chipluxPurple.withValues(alpha: .22),
                    ],
                  ),
                ),
                child: Center(
                  child: (decade != null || misc != null)
                      ? Icon(_chipluxCuratedIcon(decade, misc), color: accent, size: 38)
                      : _DiscoverVectorIcon(
                          category: category,
                          genreId: genre?.id,
                          color: accent,
                        ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  heading ??
                      _discoverHeading(
                        context,
                        DiscoverMode.top100,
                        category,
                        genre,
                      ),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: accent, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverGenreSection extends StatefulWidget {
  final DiscoverCategory category;
  final DiscoverMode mode;
  final DiscoverGenre? genre;
  const _DiscoverGenreSection({
    super.key,
    required this.category,
    required this.mode,
    this.genre,
  });
  @override
  State<_DiscoverGenreSection> createState() => _DiscoverGenreSectionState();
}

class _DiscoverGenreSectionState extends State<_DiscoverGenreSection> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Map<String, dynamic>>> _load({bool force = false}) async {
    final service = DiscoverCatalogService.instance;
    final rows = await service.load(
      widget.category,
      widget.mode,
      genreId: widget.genre?.id,
      force: force,
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _discoverHeading(context, widget.mode, widget.category, widget.genre),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SizedBox(
                height: 90,
                child: Center(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => future = _load(force: true)),
                    child: Text(
                      _discoverText(
                        context,
                        widget.category == DiscoverCategory.albums
                            ? 'Album cache is not ready or could not be reached. Retry'
                            : 'Could not load this section. Retry',
                        'Ovaj odjeljak nije učitan. Pokušaj ponovno',
                      ),
                    ),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return AnimatedBuilder(
              animation: Listenable.merge([
                LibraryService.instance,
                MusicUserDataService.instance,
                MediaUserDataService.instance,
              ]),
              builder: (context, _) {
                final candidates = widget.mode == DiscoverMode.forYou
                    ? _discoverPersonalize(widget.category, snapshot.data!)
                    : snapshot.data!;
                final rows = widget.mode == DiscoverMode.forYou
                    ? _discoverDailyPick(
                        widget.category,
                        widget.genre,
                        candidates,
                      )
                    : candidates;
                if (rows.isEmpty) {
                  return SizedBox(
                    height: 70,
                    child: Text(
                      _discoverText(
                        context,
                        'No unseen recommendations remain in this saved selection.',
                        'Nema novih preporuka u ovom spremljenom izboru.',
                      ),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  );
                }
                if (widget.mode == DiscoverMode.forYou) {
                  return DiscoverCatalogService.isMusic(widget.category)
                      ? _DiscoverMusicTile(
                          item: rows.first,
                          category: widget.category,
                          compact: true,
                        )
                      : _DiscoverDailyMediaTile(
                          item: rows.first,
                          category: widget.category,
                        );
                }
                if (!DiscoverCatalogService.isMusic(widget.category)) {
                  return _TrendingRow(
                    items: rows.take(20).toList(),
                    mediaType: DiscoverCatalogService.mediaType(
                      widget.category,
                    ),
                  );
                }
                return SizedBox(
                  height:
                      200 +
                      (MediaQuery.textScalerOf(context).scale(12) - 12) * 4,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: rows.take(20).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _DiscoverMusicTile(
                      item: rows[index],
                      category: widget.category,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

class _DiscoverRankedPage extends StatefulWidget {
  final DiscoverCategory category;
  final DiscoverGenre? genre;
  const _DiscoverRankedPage({required this.category, this.genre});
  @override
  State<_DiscoverRankedPage> createState() => _DiscoverRankedPageState();
}

class _DiscoverRankedPageState extends State<_DiscoverRankedPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<Map<String, dynamic>>> load({bool force = false}) =>
      DiscoverCatalogService.instance.load(
        widget.category,
        DiscoverMode.top100,
        genreId: widget.genre?.id,
        force: force,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: chipluxBackground,
    appBar: AppBar(
      title: Text(
        _discoverHeading(
          context,
          DiscoverMode.top100,
          widget.category,
          widget.genre,
        ),
      ),
    ),
    body: ChipluxBackground(
      style: ChipluxBackgroundStyle.discover,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => future = load(force: true)),
                child: Text(
                  _discoverText(
                    context,
                    widget.category == DiscoverCategory.albums
                        ? 'Album cache is not ready or could not be reached. Retry'
                        : 'Could not load this list. Retry',
                    'Lista nije učitana. Pokušaj ponovno',
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          final partialAlbums =
              widget.category == DiscoverCategory.albums &&
              rows.isNotEmpty &&
              rows.length < 100;
          return RefreshIndicator(
            onRefresh: () async {
              final next = load(force: true);
              setState(() => future = next);
              try {
                await next;
              } catch (_) {
                /* FutureBuilder displays the retry state. */
              }
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rows.isEmpty
                  ? 1
                  : rows.length + (partialAlbums ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (partialAlbums && index == 0) {
                  return Text(
                    _discoverText(
                      context,
                      '${rows.length} studio albums available in this genre. Pull down to refresh.',
                      '${rows.length} studijskih albuma u ovom žanru. Povuci za osvježavanje.',
                    ),
                    style: const TextStyle(color: Colors.white60),
                  );
                }
                final rowIndex = index - (partialAlbums ? 1 : 0);
                if (rows.isEmpty) {
                  return Text(
                    _discoverText(
                      context,
                      'No ranked titles available yet.',
                      'Trenutno nema rangiranih naslova.',
                    ),
                  );
                }
                if (!DiscoverCatalogService.isMusic(widget.category)) {
                  return _Top100Row(
                    rank: rowIndex + 1,
                    item: rows[rowIndex],
                    mediaType: DiscoverCatalogService.mediaType(
                      widget.category,
                    ),
                  );
                }
                return _DiscoverMusicTile(
                  item: rows[rowIndex],
                  category: widget.category,
                  compact: true,
                  rank: rowIndex + 1,
                );
              },
            ),
          );
        },
      ),
    ),
  );
}

class _DiscoverMusicTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final DiscoverCategory category;
  final bool compact;
  final int? rank;
  const _DiscoverMusicTile({
    required this.item,
    required this.category,
    this.compact = false,
    this.rank,
  });
  @override
  State<_DiscoverMusicTile> createState() => _DiscoverMusicTileState();
}

class _DiscoverMusicTileState extends State<_DiscoverMusicTile> {
  bool opening = false;
  Future<void> open() async {
    if (opening) {
      return;
    }
    setState(() => opening = true);
    try {
      late final MusicAlbum album;
      String? trackId;
      if (widget.category == DiscoverCategory.songs) {
        final mapping = widget.item['album_mapping'];
        if (mapping is! Map) {
          return;
        }
        album = MusicService.instance.albumFromMapping(mapping);
        trackId = mapping['track_id']?.toString();
      } else {
        // Canonical metadata was resolved by the daily server job.
        // Opening an album must not perform another title search.
        final cachedAlbum = _discoverAlbumFromItem(widget.item);
        if (cachedAlbum == null) {
          throw const FormatException('Invalid cached album');
        }
        album = cachedAlbum;
      }
      if (!mounted) {
        return;
      }
      final resolvedAlbum = album;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MusicAlbumPage(album: resolvedAlbum, initialTrackId: trackId),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _discoverText(
                context,
                'Could not open this title. Please try again.',
                'Naslov nije otvoren. Pokušaj ponovno.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: MusicUserDataService.instance,
    builder: (context, _) {
      final song = widget.category == DiscoverCategory.songs;
      final mapping = widget.item['album_mapping'] as Map?;
      final title = widget.item['name']?.toString() ?? '';
      final artist = widget.item['artist_name']?.toString() ?? '';
      final entries = song
          ? MusicUserDataService.instance.trackEntries
          : MusicUserDataService.instance.albumEntries;
      MusicLibraryEntry? entry;
      for (final candidate in entries) {
        if ((song && candidate.entityId == (mapping?['track_id'])) ||
            (_discoverNormalize(candidate.title) == _discoverNormalize(title) &&
                _discoverNormalize(candidate.artistName) ==
                    _discoverNormalize(artist))) {
          entry = candidate;
          break;
        }
      }
      if (!widget.compact) {
        return _TrendingAlbumCoverCard(
          item: widget.item,
          onTap: opening ? null : open,
          isFavorite: entry?.isFavorite ?? false,
        );
      }
      return _CollectionCard(
        title: title,
        subtitle: artist,
        coverUrl: widget.item['cover_url']?.toString(),
        meta: song ? (mapping?['album_title']?.toString()) : entry?.releaseYear,
        isFavorite: entry?.isFavorite ?? false,
        isCompleted: entry?.isListened ?? false,
        onTap: opening ? null : open,
        opening: opening,
        width: widget.compact ? null : 305,
        rank: widget.rank,
        showRating: false, // Ratings are displayed in Library, not Discovery.
      );
    },
  );
}

class _DiscoverDailyMediaTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final DiscoverCategory category;
  const _DiscoverDailyMediaTile({required this.item, required this.category});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      LibraryService.instance,
      CriticService.instance,
      MediaUserDataService.instance,
    ]),
    builder: (context, _) {
      final id = (item['id'] as num).toInt();
      final type = DiscoverCatalogService.mediaType(category);
      final library = LibraryService.instance.getItem(id, type);
      final critic = CriticService.instance;
      final stars = critic.titleRatingStars(id, type);
      final ratedEpisodes = type == 'tv'
          ? critic.ratedEpisodeCountForShow(id)
          : 0;
      final total = library?.totalEpisodes ?? 0;
      final fullyRated = type == 'tv'
          ? stars != null && total > 0 && ratedEpisodes >= total
          : critic.isMovieRated(id);
      final date = (item['release_date'] ?? item['first_air_date'] ?? '')
          .toString();
      final year = date.length >= 4 ? date.substring(0, 4) : '';
      final poster = item['poster_path']?.toString();
      final genres = type == 'tv' ? 'TV Show' : 'Movie';
      return _CollectionCard(
        title: (item['title'] ?? item['name'] ?? '').toString(),
        subtitle: genres,
        meta: year,
        coverUrl: poster == null
            ? null
            : 'https://image.tmdb.org/t/p/w185$poster',
        isFavorite: MediaUserDataService.instance.isFavorite(id, type),
        isCompleted: library?.status == 'completed',
        isRated: fullyRated,
        ratingStars: stars,
        ratingLabel: type == 'tv'
            ? 'Episodes rated: $ratedEpisodes / ${total > 0 ? total : '?'}'
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaDetailsPage(id: id, mediaType: type),
          ),
        ),
      );
    },
  );
}

// A For You recommendation stays on the same album and genre until the user
// changes either one. Session state is kept locally per account; preferences
// are also synced to Supabase by the existing feedback table.
// A daily recommendation is selected on the device from the cached catalog.
// The six-AM boundary is LOCAL to the user's device; no per-user cron is needed.
class _ChipluxDailyRecommendation extends StatefulWidget {
  final DiscoverCategory category;
  const _ChipluxDailyRecommendation({super.key, required this.category});

  @override
  State<_ChipluxDailyRecommendation> createState() =>
      _ChipluxDailyRecommendationState();
}

class _ChipluxDailyRecommendationState
    extends State<_ChipluxDailyRecommendation> with WidgetsBindingObserver {
  late final String accountId;
  late Future<List<DiscoverGenre>> genresFuture;
  late Future<List<Map<String, dynamic>>> future;
  SharedPreferences? prefs;
  Timer? dailyTimer;
  int? selectedGenreId;
  String? selectionKey;
  Map<String, dynamic>? selectedItem;
  String? savedDay;
  int rotation = 0;
  final skipped = <String>{};
  final recent = <String>{};
  final localEdits = <String, String>{};
  final cloudFeedback = <String, String>{};
  final changedThisSession = <String>{};
  final interestedItems = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>> latestRanked = const [];
  Future<void> pendingSave = Future<void>.value();

  String get prefix =>
      'chiplux_daily_${accountId}_${widget.category.name}_';
  String get sessionKey => '${prefix}session_v2';
  String _id(Map<String, dynamic> item) => item['id']?.toString() ?? '';
  String? _choice(String id) => cloudFeedback[id] ?? localEdits[id];
  bool get isAlbum => widget.category == DiscoverCategory.albums;
  String get mediaType => widget.category == DiscoverCategory.movies ? 'movie' : 'tv';

  // The day's recommendation changes at 06:00 local time, not at midnight.
  String _day() {
    final now = DateTime.now();
    final day = now.hour < 6 ? now.subtract(const Duration(days: 1)) : now;
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  void _scheduleNextRefresh() {
    dailyTimer?.cancel();
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 6);
    if (!next.isAfter(now)) {
      next = DateTime(now.year, now.month, now.day + 1, 6);
    }
    dailyTimer = Timer(next.difference(now) + const Duration(seconds: 1), () {
      _checkNewDay();
      _scheduleNextRefresh();
    });
  }

  void _checkNewDay() {
    if (!mounted || savedDay == _day()) {
      return;
    }
    setState(() {
      if (selectionKey != null) {
        recent.add(selectionKey!);
      }
      savedDay = _day();
      selectionKey = null;
      selectedItem = null;
      skipped.clear();
      rotation = 0;
      future = _load();
    });
    unawaited(_persist());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNewDay();
      _scheduleNextRefresh();
    }
  }

  @override
  void initState() {
    super.initState();
    accountId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    WidgetsBinding.instance.addObserver(this);
    genresFuture = DiscoverCatalogService.instance.genres(widget.category);
    future = _restore();
    _scheduleNextRefresh();
  }

  @override
  void dispose() {
    dailyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _restore() async {
    final store = await SharedPreferences.getInstance();
    if (!mounted) {
      return [];
    }
    prefs = store;
    // Preserve choices and the selected genre from the previous For You
    // implementation so existing users don't lose their saved interests.
    if (isAlbum) {
      final legacyPrefix = 'chiplux_album_discovery_${accountId}_';
      for (final key in store.getKeys().where((key) =>
          key.startsWith(legacyPrefix) &&
          key != '${legacyPrefix}recommendation_session_v1')) {
        final choice = store.getString(key);
        if (choice == 'interested' || choice == 'not_for_me') {
          localEdits[key.substring(legacyPrefix.length)] = choice!;
        }
      }
    }
    try {
      final raw = store.getString(sessionKey);
      if (raw == null && isAlbum) {
        final oldRaw = store.getString(
            'chiplux_album_discovery_${accountId}_recommendation_session_v1');
        if (oldRaw != null) {
          final old = jsonDecode(oldRaw);
          if (old is Map) {
            selectedGenreId = (old['genre_id'] as num?)?.toInt();
            savedDay = _day();
            if (old['album'] is Map) {
              selectedItem = Map<String, dynamic>.from(old['album'] as Map);
              selectionKey = _id(selectedItem!);
            }
          }
        }
      }
      if (raw != null) {
        final state = jsonDecode(raw);
        if (state is Map) {
          selectedGenreId = (state['genre_id'] as num?)?.toInt();
          if (selectedGenreId == 0) {
            selectedGenreId = null;
          }
          savedDay = state['day']?.toString();
          recent.addAll((state['recent'] as List? ?? []).whereType<String>());
          if (savedDay != _day() && state['item'] is Map) {
            final previous = (state['item'] as Map)['id']?.toString();
            if (previous != null && previous.isNotEmpty) {
              recent.add(previous);
            }
          }
          if (savedDay == _day()) {
            rotation = (state['rotation'] as num?)?.toInt() ?? 0;
            skipped.addAll((state['skipped'] as List? ?? []).whereType<String>());
            if (state['item'] is Map) {
              selectedItem = Map<String, dynamic>.from(state['item'] as Map);
              selectionKey = _id(selectedItem!);
            }
          }
          final choices = state['choices'];
          if (choices is Map) {
            for (final entry in choices.entries) {
              if (entry.value == 'interested' || entry.value == 'not_for_me') {
                localEdits[entry.key.toString()] = entry.value.toString();
              }
            }
          }
          final saved = state['interested_items'];
          if (saved is Map) {
            for (final entry in saved.entries) {
              if (entry.value is Map) {
                interestedItems[entry.key.toString()] =
                    Map<String, dynamic>.from(entry.value as Map);
              }
            }
          }
        }
      }
    } catch (_) {
      // An older/broken session must not block the discovery feed.
    }
    if (savedDay != _day()) {
      savedDay = _day();
      selectionKey = null;
      selectedItem = null;
      skipped.clear();
      rotation = 0;
    }
    if (mounted) setState(() {});
    unawaited(_readCloud());
    return _load();
  }

  Future<void> _readCloud() async {
    if (accountId == 'guest') {
      return;
    }
    try {
      final rows = isAlbum
          ? await Supabase.instance.client
              .from('chiplux_album_discovery_feedback')
              .select('album_id,preference,item')
              .eq('user_id', accountId)
          : await Supabase.instance.client
              .from('chiplux_media_discovery_feedback')
              .select('item_id,preference,item')
              .eq('user_id', accountId)
              .eq('media_type', mediaType);
      if (!mounted) {
        return;
      }
      setState(() {
        for (final record in rows) {
          final id = (record[isAlbum ? 'album_id' : 'item_id'] ?? '').toString();
          final choice = record['preference']?.toString();
          if (id.isEmpty || (choice != 'interested' && choice != 'not_for_me')) {
            continue;
          }
          // Prefer edits made during this session over an older cloud response.
          if (!changedThisSession.contains(id)) {
            cloudFeedback[id] = choice!;
          }
          if (choice == 'interested' && record['item'] is Map) {
            final restored = Map<String, dynamic>.from(record['item'] as Map);
            // Older feedback rows have no metadata yet. Keep their feedback,
            // but don't render an empty title card in the saved collection.
            if (restored['id'] != null &&
                (!isAlbum || _discoverAlbumFromItem(restored) != null)) {
              interestedItems.putIfAbsent(id, () => restored);
            }
          } else if (choice == 'not_for_me') {
            interestedItems.remove(id);
          }
        }
      });
      unawaited(_persist());
    } catch (_) {
      // The user can still discover and save feedback offline.
    }
  }

  Future<List<Map<String, dynamic>>> _load() =>
      DiscoverCatalogService.instance.load(widget.category, DiscoverMode.forYou,
          genreId: selectedGenreId);

  Future<void> _persist() {
    final store = prefs;
    if (store == null) {
      return Future<void>.value();
    }
    final data = jsonEncode({
      'day': savedDay ?? _day(),
      'genre_id': selectedGenreId ?? 0,
      'rotation': rotation,
      'item': selectedItem,
      'skipped': skipped.take(250).toList(),
      'recent': recent.toList().reversed.take(40).toList(),
      'choices': {...cloudFeedback, ...localEdits},
      'interested_items': interestedItems,
    });
    pendingSave = pendingSave.then((_) async {
      try { await store.setString(sessionKey, data); } catch (_) {}
    });
    return pendingSave;
  }

  // Stable user/day ordering within the personalized top pool, with rerolls.
  Map<String, dynamic>? _next(List<Map<String, dynamic>> ranked) {
    final available = ranked.where((item) {
      final id = _id(item);
      return id.isNotEmpty && !skipped.contains(id) &&
          _choice(id) != 'not_for_me' && _choice(id) != 'interested';
    }).toList();
    if (available.isEmpty) {
      return null;
    }
    final fresh = available.where((item) => !recent.contains(_id(item))).toList();
    // Prefer an unseen day-to-day title. Fall back only when the genre's
    // cache has no other eligible albums or shows.
    final pool = (fresh.isNotEmpty ? fresh : available).take(40).toList();
    final salt = '$accountId:${widget.category.name}:${selectedGenreId ?? 0}:${_day()}';
    var hash = 2166136261;
    for (final unit in salt.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return pool[(hash + rotation) % pool.length];
  }

  void _reroll() {
    setState(() {
      if (selectionKey != null) {
        skipped.add(selectionKey!);
      }
      rotation++;
      selectionKey = null;
      selectedItem = _next(latestRanked);
      selectionKey = selectedItem == null ? null : _id(selectedItem!);
    });
    unawaited(_persist());
  }

  void _changeGenre(int? next) {
    final id = next == 0 ? null : next;
    if (id == selectedGenreId) {
      return;
    }
    setState(() {
      selectedGenreId = id;
      selectedItem = null;
      selectionKey = null;
      skipped.clear();
      rotation = 0;
      latestRanked = const [];
      future = _load();
    });
    unawaited(_persist());
  }

  Future<void> _record(Map<String, dynamic> item, bool interested) async {
    final id = _id(item);
    if (id.isEmpty) {
      return;
    }
    final choice = interested ? 'interested' : 'not_for_me';
    setState(() {
      localEdits[id] = choice;
      changedThisSession.add(id);
      cloudFeedback[id] = choice;
      if (interested) {
        interestedItems[id] = Map<String, dynamic>.from(item);
      } else {
        interestedItems.remove(id);
        skipped.add(id);
        rotation++;
        selectedItem = _next(latestRanked);
        selectionKey = selectedItem == null ? null : _id(selectedItem!);
      }
    });
    await _persist();
    if (accountId == 'guest') {
      return;
    }
    try {
      final fields = <String, dynamic>{
        'user_id': accountId,
        'preference': choice,
        'item': item,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (isAlbum) 'album_id': id,
        if (!isAlbum) 'item_id': id,
        if (!isAlbum) 'media_type': mediaType,
      };
      await Supabase.instance.client
          .from(isAlbum ? 'chiplux_album_discovery_feedback'
              : 'chiplux_media_discovery_feedback')
          .upsert(fields, onConflict: isAlbum
              ? 'user_id,album_id' : 'user_id,media_type,item_id');
    } catch (_) {
      // Local preference persists until the backend is reachable.
    }
  }

  void _showInterested() {
    final saved = interestedItems.values.toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: chipluxBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .75,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Icon(Icons.favorite_rounded, color: chipluxCyan),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _discoverText(sheetContext, 'Interested titles', 'Naslovi koji me zanimaju'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                )),
                IconButton(icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext)),
              ]),
            ),
            Expanded(child: saved.isEmpty
                ? Center(child: Text(_discoverText(sheetContext,
                    'Mark a recommendation Interested to save it here.',
                    'Označi preporuku koja te zanima da je spremiš ovdje.')))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: saved.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => isAlbum
                        ? _DiscoverMusicTile(
                            item: saved[index], category: widget.category,
                            compact: true)
                        : _Top100Row(rank: index + 1, item: saved[index],
                            mediaType: mediaType),
                  )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DiscoverGenre>>(
    future: genresFuture,
    builder: (context, genreSnapshot) {
      final options = genreSnapshot.data ?? <DiscoverGenre>[];
      final displayedGenre = options.any((g) => g.id == selectedGenreId)
          ? selectedGenreId ?? 0 : 0;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Text(_discoverText(context,
            isAlbum ? 'An album for you' : widget.category == DiscoverCategory.movies
                ? 'A movie for you' : 'A TV show for you',
            isAlbum ? 'Album za tebe' : widget.category == DiscoverCategory.movies
                ? 'Film za tebe' : 'Serija za tebe'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_discoverText(context,
              'A fresh personalized recommendation every day at 6 AM.',
              'Nova personalizirana preporuka svaki dan u 6 ujutro.'),
              style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('chiplux-daily-${widget.category.name}-$displayedGenre'),
            initialValue: displayedGenre,
            dropdownColor: chipluxSurface,
            decoration: InputDecoration(
              labelText: _discoverText(context, 'Choose genre', 'Odaberi žanr'),
              filled: true, fillColor: chipluxSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: [
              DropdownMenuItem(value: 0,
                child: Text(_discoverText(context, 'Surprise me · All genres',
                    'Iznenadi me · Svi žanrovi'))),
              for (final g in options)
                DropdownMenuItem(value: g.id,
                  child: Text(_discoverGenreLabel(context, g))),
            ],
            onChanged: genreSnapshot.hasData ? _changeGenre : null,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(() => future = _load()),
                  child: Text(_discoverText(context, 'Could not load. Retry',
                      'Učitavanje nije uspjelo. Pokušaj ponovno')),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ));
              }
              return AnimatedBuilder(
                animation: Listenable.merge([
                  MusicUserDataService.instance,
                  LibraryService.instance,
                  MediaUserDataService.instance,
                ]),
                builder: (context, _) {
                  latestRanked = _discoverPersonalize(widget.category, snapshot.data!);
                  Map<String, dynamic>? item = selectedItem;
                  if (item != null && _choice(_id(item)) == 'not_for_me') {
                    item = null;
                  }
                  item ??= _next(latestRanked);
                  if (item == null) {
                    return Column(children: [
                      Text(_discoverText(context,
                          'No unseen titles remain in this selection.',
                          'Nema više neviđenih naslova u ovom izboru.')),
                      TextButton(onPressed: () {
                        setState(() { skipped.clear(); rotation++; selectedItem = null; selectionKey = null; });
                        unawaited(_persist());
                      }, child: Text(_discoverText(context, 'Try again', 'Pokušaj ponovno'))),
                    ]);
                  }
                  final current = item;
                  final id = _id(current);
                  if (selectionKey != id || selectedItem == null) {
                    selectionKey = id;
                    selectedItem = Map<String, dynamic>.from(current);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && selectionKey == id) {
                        unawaited(_persist());
                      }
                    });
                  }
                  final interested = _choice(id) == 'interested';
                  return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: chipluxSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: chipluxViolet.withValues(alpha: .45)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (isAlbum) _DiscoverMusicTile(
                          item: current, category: widget.category, compact: true)
                      else _DiscoverDailyMediaTile(
                          item: current, category: widget.category),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => _record(current, true),
                          icon: Icon(interested ? Icons.favorite_rounded : Icons.favorite_border),
                          label: Text(_discoverText(context, 'Interested', 'Zanima me')),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => _record(current, false),
                          icon: const Icon(Icons.thumb_down_outlined),
                          label: Text(_discoverText(context, 'Not for me', 'Nije za mene')),
                        )),
                      ]),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _reroll,
                        icon: const Icon(Icons.shuffle_rounded),
                        label: Text(_discoverText(context,
                            isAlbum ? 'Another album' : 'Another title',
                            isAlbum ? 'Drugi album' : 'Drugi naslov')),
                      ),
                    ]),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _showInterested,
            icon: const Icon(Icons.bookmarks_outlined, color: chipluxCyan),
            label: Text(_discoverText(context,
                'Saved Interested (${interestedItems.length})',
                'Spremljeni favoriti (${interestedItems.length})')),
          ),
        ],
      );
    },
  );
}

class _ChipluxCategorizedLists extends StatefulWidget {
  final DiscoverCategory category;
  const _ChipluxCategorizedLists({required this.category});
  @override
  State<_ChipluxCategorizedLists> createState() =>
      _ChipluxCategorizedListsState();
}

class _ChipluxCategorizedListsState extends State<_ChipluxCategorizedLists> {
  int tab = 0;
  @override
  void didUpdateWidget(covariant _ChipluxCategorizedLists oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) tab = 0;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            for (final (index, name) in [
              'All Time',
              'Decade',
              'Genre',
              if (widget.category == DiscoverCategory.movies) 'Misc',
            ].indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => tab = index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: tab == index
                            ? chipluxViolet.withValues(alpha: .24)
                            : chipluxSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: tab == index ? Colors.white : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (tab == 0)
        Expanded(child: _ChipluxAllTimeList(
          key: ValueKey('all-time-${widget.category.name}'),
          category: widget.category,
        ))
      else Expanded(
        child: FutureBuilder<List<DiscoverGenre>>(
          future: DiscoverCatalogService.instance.genres(widget.category),
          builder: (context, snapshot) {
            if (tab == 2 && snapshot.hasError) {
              return Center(
                child: TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry genres'),
                ),
              );
            }
            if (tab == 2 && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final options =
                <
                  ({
                    String title,
                    DiscoverGenre? genre,
                    int? startYear,
                    String? misc,
                  })
                >[];
            if (tab == 0) {
              options.add((
                title:
                    'Top 100 ${_discoverCategoryLabel(context, widget.category)} of All Time',
                genre: null,
                startYear: null,
                misc: null,
              ));
            } else if (tab == 1) {
              for (final year in [2020, 2010, 2000, 1990, 1980, 1970, 1960]) {
                options.add((
                  title: '${year}s',
                  genre: null,
                  startYear: year,
                  misc: null,
                ));
              }
            } else if (tab == 2) {
              for (final genre in snapshot.data ?? <DiscoverGenre>[]) {
                options.add((
                  title: _discoverGenreLabel(context, genre),
                  genre: genre,
                  startYear: null,
                  misc: null,
                ));
              }
            } else if (widget.category == DiscoverCategory.movies) {
              for (final item in [
                'Hidden Gems',
                'Under 90 Minutes',
                'Superhero Movies',
              ]) {
                options.add((
                  title: item,
                  genre: null,
                  startYear: null,
                  misc: item,
                ));
              }
            } else if (widget.category == DiscoverCategory.tvShows) {
              for (final item in [
                'Sitcoms & Comedy',
                'Anime & Animation',
                'Documentaries',
                'Crime Series',
              ]) {
                options.add((
                  title: item,
                  genre: null,
                  startYear: null,
                  misc: item,
                ));
              }
            } else {
              for (final item in [
                'Hidden Gems',
                'Modern Classics',
                '90s Albums',
                'Instrumental',
                'Soundtracks',
              ]) {
                options.add((
                  title: item,
                  genre: null,
                  startYear: null,
                  misc: item,
                ));
              }
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DiscoverRankedCard(
                    category: widget.category,
                    genre: option.genre,
                    colorIndex: index,
                    heading: option.title,
                    decade: option.startYear,
                    misc: option.misc,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ChipluxCuratedListPage(
                          category: widget.category,
                          title: option.title,
                          genre: option.genre,
                          startYear: option.startYear,
                          misc: option.misc,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

// All Time displays its ranked titles immediately, without an extra card/tap.
class _ChipluxAllTimeList extends StatefulWidget {
  final DiscoverCategory category;
  const _ChipluxAllTimeList({super.key, required this.category});
  @override
  State<_ChipluxAllTimeList> createState() => _ChipluxAllTimeListState();
}

class _ChipluxAllTimeListState extends State<_ChipluxAllTimeList> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }
  Future<List<Map<String, dynamic>>> _load({bool force = false}) =>
      DiscoverCatalogService.instance.curatedList(
        widget.category, force: force);
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: TextButton(
          onPressed: () => setState(() => future = _load(force: true)),
          child: Text(_discoverText(context, 'Could not load. Retry',
              'Učitavanje nije uspjelo. Pokušaj ponovno')),
        ));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = snapshot.data!;
      return RefreshIndicator(
        onRefresh: () async {
          final next = _load(force: true);
          setState(() => future = next);
          await next;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: rows.isEmpty ? 1 : rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (rows.isEmpty) {
              return Text(_discoverText(context,
                  'No titles available. Pull down to retry.',
                  'Nema naslova. Povuci za ponovno učitavanje.'));
            }
            final row = rows[index];
            return DiscoverCatalogService.isMusic(widget.category)
                ? _DiscoverMusicTile(
                    item: row, category: widget.category,
                    compact: true, rank: index + 1)
                : _Top100Row(rank: index + 1, item: row,
                    mediaType: DiscoverCatalogService.mediaType(widget.category));
          },
        ),
      );
    },
  );
}

class _ChipluxCuratedListPage extends StatefulWidget {
  final DiscoverCategory category;
  final String title;
  final DiscoverGenre? genre;
  final int? startYear;
  final String? misc;
  const _ChipluxCuratedListPage({
    required this.category,
    required this.title,
    this.genre,
    this.startYear,
    this.misc,
  });
  @override
  State<_ChipluxCuratedListPage> createState() =>
      _ChipluxCuratedListPageState();
}

class _ChipluxCuratedListPageState extends State<_ChipluxCuratedListPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Map<String, dynamic>>> _load({bool force = false}) =>
      DiscoverCatalogService.instance.curatedList(
        widget.category,
        genreId: widget.genre?.id,
        startYear: widget.startYear,
        misc: widget.misc,
        force: force,
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: chipluxBackground,
    appBar: AppBar(title: Text(widget.title)),
    body: ChipluxBackground(
      style: ChipluxBackgroundStyle.discover,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => future = _load(force: true)),
                child: Text(
                  _discoverText(
                    context,
                    'Could not load. Retry',
                    'Učitavanje nije uspjelo. Pokušaj ponovno',
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return Center(
              child: Text(
                _discoverText(
                  context,
                  'No titles available in this selection.',
                  'Nema naslova u ovom izboru.',
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final f = _load(force: true);
              setState(() => future = f);
              await f;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  DiscoverCatalogService.isMusic(widget.category)
                  ? _DiscoverMusicTile(
                      item: rows[index],
                      category: widget.category,
                      compact: true,
                      rank: index + 1,
                    )
                  : _Top100Row(
                      rank: index + 1,
                      item: rows[index],
                      mediaType: DiscoverCatalogService.mediaType(
                        widget.category,
                      ),
                    ),
            ),
          );
        },
      ),
    ),
  );
}
