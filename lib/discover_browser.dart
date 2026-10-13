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
    'Fitness & Workout': 'Fitness i trening',
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

List<Map<String, dynamic>> _discoverPersonalize(
  DiscoverCategory category,
  List<Map<String, dynamic>> rows,
) {
  final weights = <int, double>{};
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
  double score(Map<String, dynamic> row) => (row['genre_ids'] as List? ?? [])
      .fold<double>(0, (sum, g) => sum + (weights[g] ?? 0));
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
  final pool = rows.take(20).toList();
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
              for (final value in DiscoverCategory.values)
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

class _DiscoverRankedCard extends StatelessWidget {
  final DiscoverCategory category;
  final DiscoverGenre? genre;
  final VoidCallback onTap;
  final int colorIndex;
  final String? heading;
  const _DiscoverRankedCard({
    required this.category,
    this.genre,
    required this.onTap,
    required this.colorIndex,
    this.heading,
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
                  child: _DiscoverVectorIcon(
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
    if (widget.category == DiscoverCategory.songs) {
      if (widget.mode == DiscoverMode.forYou) {
        final candidates = _discoverPersonalize(
          widget.category,
          rows,
        ).take(20).toList();
        final preferred = _discoverDailyPick(
          widget.category,
          widget.genre,
          candidates,
        );
        if (preferred.isEmpty) {
          return [];
        }
        final first = candidates.indexOf(preferred.first);
        return _discoverResolveDailySong(
          candidates,
          first,
          MusicService.instance.resolveChartSong,
        );
      }
      return MusicService.instance.prepareChartSongs(rows.take(12).toList());
    }
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
                        'Could not load this section. Retry',
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
                        'No titles available in this section yet.',
                        'Trenutno nema dostupnih naslova u ovom odjeljku.',
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
                      (154 * MediaQuery.textScalerOf(context).scale(14) / 14)
                          .clamp(154, 308)
                          .toDouble(),
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

  List<Map<String, dynamic>> songPool = [];
  List<Map<String, dynamic>> wiredSongs = [];
  int songOffset = 0;
  bool moreLoading = false;
  String? moreError;
  Future<List<Map<String, dynamic>>> load({bool force = false}) async {
    final rows = await DiscoverCatalogService.instance.load(
      widget.category,
      DiscoverMode.top100,
      genreId: widget.genre?.id,
      force: force,
    );
    if (widget.category != DiscoverCategory.songs) {
      return rows;
    }
    songPool = rows;
    songOffset = 0;
    wiredSongs = [];
    return nextSongs();
  }

  Future<List<Map<String, dynamic>>> nextSongs() async {
    final batch = songPool.skip(songOffset).take(12).toList();
    final resolved = await MusicService.instance.prepareChartSongs(batch);
    songOffset += batch.length;
    wiredSongs.addAll(resolved);
    return List.of(wiredSongs);
  }

  Future<void> loadMore() async {
    if (moreLoading) {
      return;
    }
    setState(() {
      moreLoading = true;
      moreError = null;
    });
    try {
      final rows = await nextSongs();
      if (mounted) {
        setState(() => future = Future.value(rows));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => moreError = _discoverText(
            context,
            'Could not load songs. Retry.',
            'Pjesme nisu učitane. Pokušaj ponovno.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => moreLoading = false);
      }
    }
  }

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
                    'Could not load this list. Retry',
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
              itemCount:
                  (rows.isEmpty ? 1 : rows.length) +
                  (widget.category == DiscoverCategory.songs &&
                          songOffset < songPool.length
                      ? 1
                      : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == (rows.isEmpty ? 1 : rows.length)) {
                  return Center(
                    child: TextButton(
                      onPressed: moreLoading ? null : loadMore,
                      child: moreLoading
                          ? const CircularProgressIndicator()
                          : Text(
                              moreError ??
                                  _discoverText(
                                    context,
                                    'Load more songs',
                                    'Učitaj još pjesama',
                                  ),
                            ),
                    ),
                  );
                }
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
                    rank: index + 1,
                    item: rows[index],
                    mediaType: DiscoverCatalogService.mediaType(
                      widget.category,
                    ),
                  );
                }
                return _DiscoverMusicTile(
                  item: rows[index],
                  category: widget.category,
                  compact: true,
                  rank:
                      (rows[index]['chart_rank'] as num?)?.toInt() ?? index + 1,
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
        final title = widget.item['name']?.toString() ?? '';
        final artist = widget.item['artist_name']?.toString() ?? '';
        final cleanTitle = title.replaceAll(RegExp(r'["\\]'), ' ');
        final cleanArtist = artist.replaceAll(RegExp(r'["\\]'), ' ');
        final results = await MusicService.instance.searchStudioAlbums(
          'releasegroup:"$cleanTitle" AND artist:"$cleanArtist"',
        );
        final exact =
            results
                .where(
                  (result) =>
                      _discoverNormalize(result.album.title) ==
                          _discoverNormalize(title) &&
                      _discoverNormalize(result.album.artistName) ==
                          _discoverNormalize(artist),
                )
                .toList()
              ..sort((a, b) => b.score.compareTo(a.score));
        if (exact.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _discoverText(
                    context,
                    'Album not found.',
                    'Album nije pronađen.',
                  ),
                ),
              ),
            );
          }
          return;
        }
        album = exact.first.album;
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
      final progress = !song && entry != null
          ? _musicAlbumRatingProgress(entry.entityId)
          : null;
      return _CollectionCard(
        title: title,
        subtitle: artist,
        coverUrl: widget.item['cover_url']?.toString(),
        meta: song ? (mapping?['album_title']?.toString()) : entry?.releaseYear,
        isFavorite: entry?.isFavorite ?? false,
        isCompleted: entry?.isListened ?? false,
        isRated: entry?.rating != null && (progress?.complete ?? true),
        ratingStars: entry?.ratingStars,
        ratingLabel: progress?.label,
        onTap: opening ? null : open,
        opening: opening,
        width: widget.compact ? null : 305,
        rank: widget.rank,
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

Future<List<Map<String, dynamic>>> _discoverResolveDailySong(
  List<Map<String, dynamic>> candidates,
  int start,
  Future<Map<String, dynamic>?> Function(Map<String, dynamic>) resolve,
) async {
  if (candidates.isEmpty) {
    return [];
  }
  // Resolve just one daily selection, with at most two album-match fallbacks.
  for (var i = 0; i < math.min(3, candidates.length); i++) {
    final result = await resolve(candidates[(start + i) % candidates.length]);
    if (result != null) {
      return [result];
    }
  }
  return [];
}
