import 'dart:convert';

import 'package:http/http.dart' as http;

class TmdbService {
  static const String apiKey = '37c51a3dfe32f43b32a7e91b0ac855a1';

  static const String baseUrl = 'https://api.themoviedb.org/3';

  Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final url = Uri.parse(
      '$baseUrl/search/multi'
      '?api_key=$apiKey'
      '&query=${Uri.encodeComponent(query)}'
      '&include_adult=false',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final List<dynamic> results = data['results'];

      // Remove people from results.
      return results.where((item) {
        return item['media_type'] == 'movie' || item['media_type'] == 'tv';
      }).toList();
    }

    throw Exception('Failed to search TMDB');
  }


  Future<List<dynamic>> searchPeople(String query) async {
    final clean = query.trim();

    if (clean.isEmpty) {
      return [];
    }

    final url = Uri.parse(
      '$baseUrl/search/person'
      '?api_key=$apiKey'
      '&query=${Uri.encodeComponent(clean)}'
      '&include_adult=false'
      '&page=1',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to search people');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> results = List<dynamic>.from(data['results'] ?? const []);

    results.sort((a, b) {
      final aPopularity = a is Map && a['popularity'] is num
          ? (a['popularity'] as num).toDouble()
          : 0.0;
      final bPopularity = b is Map && b['popularity'] is num
          ? (b['popularity'] as num).toDouble()
          : 0.0;
      return bPopularity.compareTo(aPopularity);
    });

    return results;
  }

  Future<Map<String, dynamic>> getDetails(int id, String mediaType) async {
    final append = mediaType == 'movie' ? 'release_dates' : 'content_ratings';

    final url = Uri.parse(
      '$baseUrl/$mediaType/$id'
      '?api_key=$apiKey'
      '&append_to_response=$append',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load details');
  }

  Future<List<dynamic>> getSeasonEpisodes(int showId, int seasonNumber) async {
    final url = Uri.parse(
      '$baseUrl/tv/$showId/season/$seasonNumber'
      '?api_key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data['episodes'] ?? [];
    }

    throw Exception('Failed to load episodes');
  }

  Future<List<dynamic>> getTrendingTv() async {
    final url = Uri.parse(
      '$baseUrl/trending/tv/week'
      '?api_key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data['results'] ?? [];
    }

    throw Exception('Failed to load trending TV shows');
  }

  Future<List<dynamic>> getTrendingMovies() async {
    final url = Uri.parse(
      '$baseUrl/trending/movie/week'
      '?api_key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data['results'] ?? [];
    }

    throw Exception('Failed to load trending movies');
  }

  Future<List<dynamic>> getTrendingAnime() async {
    final url = Uri.parse(
      '$baseUrl/discover/tv'
      '?api_key=$apiKey'
      '&with_genres=16'
      '&with_original_language=ja'
      '&sort_by=popularity.desc',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data['results'] ?? [];
    }

    throw Exception('Failed to load trending anime');
  }

  static int? _superheroKeywordId;

  Uri _buildUri(String path, {Map<String, String> query = const {}}) {
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: {'api_key': apiKey, ...query});
  }

  Future<List<dynamic>> _getResults(Uri url) async {
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'TMDB request failed: '
        '${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    return List<dynamic>.from(data['results'] ?? []);
  }

  Future<List<dynamic>> _getPagedResults({
    required String path,
    Map<String, String> query = const {},
    int pages = 5,
    int limit = 100,
  }) async {
    final futures = List.generate(pages, (index) {
      return _getResults(
        _buildUri(path, query: {...query, 'page': '${index + 1}'}),
      );
    });

    final pageResults = await Future.wait(futures);

    final combined = <dynamic>[];

    final seenIds = <int>{};

    for (final page in pageResults) {
      for (final item in page) {
        final rawId = item['id'];

        if (rawId is! num) {
          continue;
        }

        final id = rawId.toInt();

        if (!seenIds.add(id)) {
          continue;
        }

        combined.add(item);

        if (combined.length >= limit) {
          return combined;
        }
      }
    }

    return combined;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ======================================================
  // TOP 100 LISTS
  // ======================================================

  Future<List<dynamic>> getTop100Movies() {
    return _getPagedResults(
      path: '/movie/top_rated',
      pages: 5,
      limit: 100,
      query: const {'language': 'en-US'},
    );
  }

  Future<List<dynamic>> getTop100TvShows() {
    return _getPagedResults(
      path: '/tv/top_rated',
      pages: 5,
      limit: 100,
      query: const {'language': 'en-US'},
    );
  }

  Future<List<dynamic>> getTop100ShortMovies() {
    return _getPagedResults(
      path: '/discover/movie',
      pages: 5,
      limit: 100,
      query: const {
        'language': 'en-US',
        'include_adult': 'false',
        'include_video': 'false',

        'sort_by': 'vote_average.desc',

        // Don't let a movie with
        // 7 votes become #1.
        'vote_count.gte': '300',

        // 90 minutes or shorter.
        'with_runtime.lte': '90',
      },
    );
  }

  Future<int?> _findKeywordId(String keyword) async {
    final results = await _getResults(
      _buildUri('/search/keyword', query: {'query': keyword}),
    );

    if (results.isEmpty) {
      return null;
    }

    // Prefer exact keyword match.
    for (final result in results) {
      final name = (result['name'] ?? '').toString().toLowerCase();

      if (name == keyword.toLowerCase()) {
        final id = result['id'];

        if (id is num) {
          return id.toInt();
        }
      }
    }

    final firstId = results.first['id'];

    return firstId is num ? firstId.toInt() : null;
  }

  Future<List<dynamic>> getTop100SuperheroMovies() async {
    _superheroKeywordId ??= await _findKeywordId('superhero');

    final keywordId = _superheroKeywordId;

    if (keywordId == null) {
      return [];
    }

    return _getPagedResults(
      path: '/discover/movie',
      pages: 5,
      limit: 100,
      query: {
        'language': 'en-US',
        'include_adult': 'false',
        'include_video': 'false',
        'sort_by': 'vote_average.desc',
        'vote_count.gte': '300',
        'with_keywords': '$keywordId',
      },
    );
  }

  Future<List<dynamic>> getTop100HiddenGems() {
    return _getPagedResults(
      path: '/discover/movie',
      pages: 5,
      limit: 100,
      query: const {
        'language': 'en-US',
        'include_adult': 'false',
        'include_video': 'false',

        'sort_by': 'vote_average.desc',

        // Chiplux "Hidden Gem"
        // definition for now.
        'vote_average.gte': '7.0',
        'vote_count.gte': '300',
        'vote_count.lte': '5000',
      },
    );
  }

  // ======================================================
  // TODAY
  // ======================================================

  Future<List<dynamic>> getDailyMoviePool() {
    return _getPagedResults(
      path: '/discover/movie',
      pages: 3,
      limit: 60,
      query: const {
        'language': 'en-US',
        'include_adult': 'false',
        'include_video': 'false',
        'sort_by': 'popularity.desc',
        'vote_average.gte': '6.5',
        'vote_count.gte': '800',
      },
    );
  }

  Future<List<dynamic>> getDailyTvPool() {
    return _getPagedResults(
      path: '/discover/tv',
      pages: 3,
      limit: 60,
      query: const {
        'language': 'en-US',
        'include_adult': 'false',
        'sort_by': 'popularity.desc',
        'vote_average.gte': '6.5',
        'vote_count.gte': '500',
      },
    );
  }

  Future<List<dynamic>> getMoviesReleasedOn(DateTime date) {
    final day = _formatDate(date);

    return _getPagedResults(
      path: '/discover/movie',
      pages: 2,
      limit: 40,
      query: {
        'language': 'en-US',
        'include_adult': 'false',
        'include_video': 'false',
        'sort_by': 'popularity.desc',
        'primary_release_date.gte': day,
        'primary_release_date.lte': day,
      },
    );
  }

  Future<List<dynamic>> getTvAiringOn(DateTime date) {
    final day = _formatDate(date);

    return _getPagedResults(
      path: '/discover/tv',
      pages: 2,
      limit: 40,
      query: {
        'language': 'en-US',
        'include_adult': 'false',
        'sort_by': 'popularity.desc',
        'air_date.gte': day,
        'air_date.lte': day,
      },
    );
  }

  Future<Map<String, dynamic>> getCredits(int id, String mediaType) async {
    final url = _buildUri(
      '/$mediaType/$id/credits',
      query: const {'language': 'en-US'},
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    throw Exception('Failed to load credits');
  }

  Future<Map<String, dynamic>> getPersonCombinedCredits(int personId) async {
    final url = _buildUri(
      '/person/$personId/combined_credits',
      query: const {'language': 'en-US'},
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    throw Exception('Failed to load person projects');
  }
}
