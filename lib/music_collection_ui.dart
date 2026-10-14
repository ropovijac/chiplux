part of 'main.dart';

({String label, bool complete}) _musicAlbumRatingProgress(String albumId) {
  final tracks = MusicUserDataService.instance.trackEntries
      .where((e) => e.albumId == albumId)
      .toList();
  final details = MusicService.instance.cachedAlbumDetails(albumId);
  final rated = details == null
      ? tracks.where((e) => e.rating != null).length
      : details.tracks
            .where(
              (track) =>
                  MusicUserDataService.instance.trackState(track.id).rating !=
                  null,
            )
            .length;
  final total = details?.tracks.length;
  return (
    label: 'Songs rated: $rated${total == null ? '' : ' / $total'}',
    complete: total != null && total > 0 && rated >= total,
  );
}

// One flexible card for music collections and all daily recommendations.
class _CollectionCard extends StatelessWidget {
  final String title, subtitle;
  final String? coverUrl, meta, ratingLabel, status;
  final VoidCallback? onTap;
  final bool isFavorite, isCompleted, isRated, opening, showTracking;
  final int? ratingStars;
  final int? rank;
  final double? width;
  const _CollectionCard({
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.meta,
    this.onTap,
    this.isFavorite = false,
    this.isCompleted = false,
    this.isRated = false,
    this.ratingStars,
    this.ratingLabel,
    this.status,
    this.opening = false,
    this.width,
    this.rank,
    this.showTracking = true,
  });
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC857),
        red = Color(0xFFFF5C72),
        green = Color(0xFF7BE8A8);
    final base = isRated
        ? gold
        : isCompleted
        ? green
        : chipluxCyan.withValues(alpha: .25);
    final frame = isFavorite
        ? [isRated || isCompleted ? base : red, red]
        : [base, base];
    final indicators = <Widget>[
      if (isCompleted)
        const Icon(Icons.check_circle_rounded, size: 15, color: green),
      if (isFavorite) const Icon(Icons.favorite_rounded, size: 15, color: red),
      if (ratingStars != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 15, color: gold),
            const SizedBox(width: 3),
            Text(
              '$ratingStars',
              style: const TextStyle(
                color: gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        )
      else
        const Text(
          'Not rated',
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      if (ratingLabel != null)
        Text(
          ratingLabel!,
          style: TextStyle(
            color: isRated ? gold : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      if (status != null)
        Text(
          trUi(context, status!),
          style: TextStyle(
            color: status == 'Dropped' ? red : chipluxPurple,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
    ];
    return Container(
      width: width,
      padding: const EdgeInsets.all(1.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: frame),
      ),
      child: Material(
        color: chipluxSurface,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                if (rank != null) ...[
                  SizedBox(
                    width: 35,
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: chipluxCyan,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: coverUrl != null && coverUrl!.isNotEmpty
                      ? Image.network(
                          coverUrl!,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _artFallback(),
                        )
                      : _artFallback(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: chipluxPurple,
                          ),
                        ),
                      ],
                      if (meta?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                      if (showTracking) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 7,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: indicators,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                if (opening)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.white38,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _artFallback() => Container(
    width: 68,
    height: 68,
    color: chipluxSurfaceLight,
    child: const Icon(Icons.library_music_rounded, color: Colors.white30),
  );
}

class _AlbumTrackCard extends StatelessWidget {
  final int number;
  final MusicTrack track;
  final MusicUserDataState state;
  final bool selected;
  final VoidCallback? onListened, onFavorite, onRate;
  const _AlbumTrackCard({
    required this.number,
    required this.track,
    required this.state,
    required this.selected,
    this.onListened,
    this.onFavorite,
    this.onRate,
  });
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC857),
        red = Color(0xFFFF5C72),
        green = Color(0xFF7BE8A8);
    final accent = selected
        ? chipluxCyan
        : state.rating != null
        ? gold
        : state.isListened
        ? green
        : chipluxViolet;
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: .65),
            state.isFavorite ? red : accent.withValues(alpha: .20),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 11, 8, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: .10), chipluxSurface],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (track.durationLabel.isNotEmpty)
                        Text(
                          track.durationLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: trUi(context, 'Listened'),
                        onPressed: onListened,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          state.isListened
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: state.isListened ? green : Colors.white38,
                          size: 22,
                        ),
                      ),
                      IconButton(
                        tooltip: trUi(context, 'Favorite'),
                        onPressed: onFavorite,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          state.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: state.isFavorite ? red : Colors.white38,
                          size: 22,
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onRate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 9,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                state.ratingStars != null
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: state.ratingStars != null
                                    ? gold
                                    : Colors.white38,
                                size: 22,
                              ),
                              if (state.ratingStars != null)
                                Text(
                                  '${state.ratingStars}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MusicMemberWorksPage extends StatefulWidget {
  final MusicMember member;
  const MusicMemberWorksPage({super.key, required this.member});
  @override
  State<MusicMemberWorksPage> createState() => _MusicMemberWorksPageState();
}

class _MusicMemberWorksPageState extends State<MusicMemberWorksPage> {
  late Future<Map<String, dynamic>> credits;
  late Future<List<MusicAlbum>> albums;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    credits = MusicService.instance.getMemberCredits(widget.member.id);
    albums = MusicService.instance.getStudioAlbums(
      widget.member.id,
      fallbackArtistName: widget.member.name,
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: chipluxBackground,
      appBar: AppBar(
        title: Text(widget.member.name),
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.mic_rounded), text: 'Performing'),
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Writing'),
          ],
        ),
      ),
      body: ChipluxBackground(
        style: ChipluxBackgroundStyle.discover,
        child: TabBarView(children: [_performing(), _writing()]),
      ),
    ),
  );
  Widget _performing() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _CollectionCard(
        title: widget.member.name,
        subtitle: widget.member.roleLabel,
        showTracking: false,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MusicArtistPage(
              artistId: widget.member.id,
              initialName: widget.member.name,
              initialType: 'Person',
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const UiText(
        'Studio Albums',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      FutureBuilder<List<MusicAlbum>>(
        future: albums,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _retry();
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const _MusicInfoNotice(
              icon: Icons.album_outlined,
              text: 'No solo studio albums found.',
            );
          }
          return Column(
            children: [
              for (final album in snapshot.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MusicAlbumCard(
                    album: album,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MusicAlbumPage(album: album),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      FutureBuilder<Map<String, dynamic>>(
        future: credits,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _retry();
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final relations = (snapshot.data!['relations'] as List? ?? [])
              .whereType<Map>()
              .toList();
          final bands = relations
              .where(
                (r) =>
                    r['type'] == 'member of band' &&
                    r['artist'] is Map &&
                    r['direction'] == 'forward',
              )
              .toList();
          final recordings = relations
              .where((r) => r['recording'] is Map)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bands.isNotEmpty) ...[
                const UiText(
                  'Bands & Groups',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final relation in bands) _bandCard(relation),
                const SizedBox(height: 20),
              ],
              if (recordings.isNotEmpty) ...[
                const UiText(
                  'Performance Credits',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final relation in recordings)
                  _creditCard(relation, 'recording'),
              ],
            ],
          );
        },
      ),
    ],
  );
  Widget _writing() => FutureBuilder<Map<String, dynamic>>(
    future: credits,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _retry();
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = (snapshot.data!['relations'] as List? ?? [])
          .whereType<Map>()
          .where(
            (r) =>
                r['work'] is Map &&
                const {
                  'composer',
                  'lyricist',
                  'writer',
                  'arranger',
                  'translator',
                  'librettist',
                  'revised by',
                }.contains(r['type']),
          )
          .toList();
      if (rows.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: _MusicInfoNotice(
            icon: Icons.edit_note_rounded,
            text: 'No writing credits found.',
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _creditCard(rows[index], 'work'),
      );
    },
  );
  Widget _bandCard(Map relation) {
    final band = relation['artist'] as Map;
    final name = band['name']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _CollectionCard(
        title: name,
        showTracking: false,
        subtitle: (relation['attributes'] as List? ?? []).join(', '),
        meta: relation['ended'] == true ? 'Former member' : 'Member',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MusicArtistPage(
              artistId: band['id'].toString(),
              initialName: name,
              initialType: band['type']?.toString() ?? 'Group',
            ),
          ),
        ),
      ),
    );
  }

  Widget _creditCard(Map relation, String entity) {
    final target = relation[entity] as Map;
    final role = [
      relation['type']?.toString() ?? '',
      ...(relation['attributes'] as List? ?? []).map((e) => e.toString()),
    ].where((e) => e.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [chipluxViolet.withValues(alpha: .16), chipluxSurface],
          ),
          border: Border.all(color: chipluxViolet.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Icon(
              entity == 'work'
                  ? Icons.edit_note_rounded
                  : Icons.music_note_rounded,
              color: chipluxPurple,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target['title']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _retry() => Center(
    child: TextButton.icon(
      onPressed: () => setState(_load),
      icon: const Icon(Icons.refresh),
      label: const UiText('Retry'),
    ),
  );
}

class _TrendingAlbumCoverCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  final bool isFavorite;
  final int? ratingStars;
  const _TrendingAlbumCoverCard({
    required this.item,
    this.onTap,
    required this.isFavorite,
    this.ratingStars,
  });
  @override
  Widget build(BuildContext context) {
    final album = item['_validated_album'] as MusicAlbum;
    final source = item['cover_url']?.toString();
    final cover = source == null || source.isEmpty
        ? album.coverUrl
        : source.replaceAll(RegExp(r'\d+x\d+bb'), '300x300bb');
    return SizedBox(
      width: 156,
      child: Material(
        color: chipluxSurface,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        cover,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 140,
                          height: 140,
                          color: chipluxSurfaceLight,
                          child: const Icon(
                            Icons.album_rounded,
                            size: 40,
                            color: Colors.white30,
                          ),
                        ),
                      ),
                    ),
                    if (isFavorite)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 20,
                          color: Color(0xFFFF5C72),
                          shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        album.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    if (ratingStars != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Color(0xFFFFC857),
                      ),
                      Text(
                        '$ratingStars',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFFFC857),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicLibraryFramedCard extends StatefulWidget {
  final MusicLibraryEntry entry;
  final VoidCallback onTap;
  const _MusicLibraryFramedCard({required this.entry, required this.onTap});
  @override
  State<_MusicLibraryFramedCard> createState() =>
      _MusicLibraryFramedCardState();
}

class _MusicLibraryFramedCardState extends State<_MusicLibraryFramedCard> {
  Future<MusicAlbumDetails>? details;
  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void didUpdateWidget(covariant _MusicLibraryFramedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.entityId != widget.entry.entityId ||
        oldWidget.entry.entityType != widget.entry.entityType) {
      _loadDetails();
    }
  }

  void _loadDetails() {
    // Only visible album cards load track metadata, independently of the list.
    details = widget.entry.isAlbum
        ? MusicService.instance.getAlbumDetails(widget.entry.toAlbum())
        : null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MusicAlbumDetails>(
    future: details,
    builder: (context, snapshot) => AnimatedBuilder(
      animation: MusicUserDataService.instance,
      builder: (context, _) => _card(snapshot.data),
    ),
  );
  Widget _card(MusicAlbumDetails? details) {
    final entry = widget.entry;
    final service = MusicUserDataService.instance;
    final state = entry.isAlbum
        ? service.albumState(entry.entityId)
        : service.trackState(entry.entityId);
    final total = details?.tracks.length;
    final rated = details == null
        ? service.trackEntries
              .where((e) => e.albumId == entry.entityId && e.rating != null)
              .length
        : details.tracks
              .where((t) => service.trackState(t.id).rating != null)
              .length;
    final fullyRated =
        state.rating != null &&
        (!entry.isAlbum || (total != null && total > 0 && rated >= total));
    final favorite = state.isFavorite;
    const gold = Color(0xFFFFC857),
        red = Color(0xFFFF5C72),
        green = Color(0xFF7BE8A8);
    final ratingColor = fullyRated ? gold : Colors.white38;
    final colors = fullyRated && favorite
        ? [gold, red]
        : fullyRated
        ? [gold, gold]
        : favorite
        ? [red, red]
        : [
            Colors.white.withValues(alpha: .05),
            Colors.white.withValues(alpha: .05),
          ];
    final compact = entry.isTrack;
    final size = compact ? 42.0 : 70.0;
    final cover = entry.coverUrl;
    Widget pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .55), width: .8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(fullyRated || favorite ? 1.4 : 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                if (fullyRated)
                  BoxShadow(color: gold.withValues(alpha: .08), blurRadius: 12),
                if (favorite)
                  BoxShadow(color: red.withValues(alpha: .07), blurRadius: 12),
              ],
            ),
            child: Material(
              color: chipluxSurface,
              borderRadius: BorderRadius.circular(15),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Container(
                  constraints: BoxConstraints(minHeight: compact ? 64 : 96),
                  padding: EdgeInsets.fromLTRB(8, compact ? 9 : 12, 8, 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: cover != null && cover.isNotEmpty
                            ? Image.network(
                                cover,
                                width: size,
                                height: size,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => SizedBox(
                                  width: size,
                                  height: size,
                                  child: const Icon(
                                    Icons.album_outlined,
                                    color: Colors.white30,
                                  ),
                                ),
                              )
                            : SizedBox(
                                width: size,
                                height: size,
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white30,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 13 : 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              compact && entry.albumTitle?.isNotEmpty == true
                                  ? '${entry.artistName} · ${entry.albumTitle}'
                                  : [
                                      entry.artistName,
                                      if (entry.releaseYear.isNotEmpty)
                                        entry.releaseYear,
                                    ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 10 : 11,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (state.isListened)
                                  pill('Completed', green)
                                else if (entry.isPlanned)
                                  pill('Plan', chipluxPurple)
                                else if (entry.isDropped)
                                  pill('Dropped', red),
                                if (entry.isAlbum)
                                  pill(
                                    'Rated Songs $rated/${total ?? '?'}',
                                    ratingColor,
                                  )
                                else
                                  pill(
                                    state.rating != null
                                        ? 'Rated'
                                        : 'Not Rated',
                                    ratingColor,
                                  ),
                                if (favorite) pill('Favorited', red),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -11,
            left: 18,
            child: Container(
              height: 27,
              padding: EdgeInsets.symmetric(
                horizontal: state.ratingStars != null ? 8 : 4,
              ),
              decoration: BoxDecoration(
                color: chipluxSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: fullyRated ? gold : Colors.white24,
                  width: 1.4,
                ),
                boxShadow: [
                  if (fullyRated)
                    BoxShadow(
                      color: gold.withValues(alpha: .20),
                      blurRadius: 8,
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 17, color: ratingColor),
                  if (state.ratingStars != null) ...[
                    const SizedBox(width: 3),
                    Text(
                      '${state.ratingStars}',
                      style: TextStyle(
                        color: ratingColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (favorite)
            Positioned(
              top: -11,
              right: 18,
              child: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: chipluxSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: red, width: 1.4),
                  boxShadow: [
                    BoxShadow(color: red.withValues(alpha: .22), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.favorite_rounded, size: 16, color: red),
              ),
            ),
        ],
      ),
    );
  }
}
