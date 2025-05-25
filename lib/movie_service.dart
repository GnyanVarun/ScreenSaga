import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:intl/intl.dart';

class ApiService {
  final String apiKey = 'e7afa1d9a7f465737e265fb314b7d391';
  final String baseUrl = 'https://api.themoviedb.org/3';

  Future<List<dynamic>> fetchMovies({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/popular?api_key=$apiKey&page=$page'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['results'];
    } else {
      throw Exception('Failed to load movies');
    }
  }

  Future<List<dynamic>> fetchTVSeries({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv/popular?api_key=$apiKey&page=$page'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['results'];
    } else {
      throw Exception('Failed to load TV series');
    }
  }

  Future<List<dynamic>> searchMovies({required String query}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/search/movie?api_key=$apiKey&query=$query'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['results'];
    } else {
      throw Exception('Failed to search movies');
    }
  }

  Future<List<dynamic>> searchTVSeries({required String query}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/search/tv?api_key=$apiKey&query=$query'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['results'];
    } else {
      throw Exception('Failed to search TV series');
    }
  }

  /// 🔍 Combined search for both movies and TV series
  Future<List<Map<String, dynamic>>> searchAllContent({required String query}) async {
    try {
      final movies = await searchMovies(query: query);
      final tvSeries = await searchTVSeries(query: query);

      final movieResults = movies.map<Map<String, dynamic>>((movie) {
        final castedMovie = Map<String, dynamic>.from(movie);
        castedMovie['type'] = 'movie';
        castedMovie['title'] = movie['title'] ?? '';
        return castedMovie;
      }).toList();

      final tvResults = tvSeries.map<Map<String, dynamic>>((tv) {
        final castedTV = Map<String, dynamic>.from(tv);
        castedTV['type'] = 'tv';
        castedTV['title'] = tv['name'] ?? '';
        return castedTV;
      }).toList();

      return [...movieResults, ...tvResults];
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }


  Future<List<dynamic>> fetchMovieCast(int movieId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/$movieId/credits?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['cast'];
    } else {
      throw Exception('Failed to load movie cast');
    }
  }

  Future<List<dynamic>> fetchTVCast(int tvId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv/$tvId/credits?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['cast'];
    } else {
      throw Exception('Failed to load TV series cast');
    }
  }

  Future<Map<String, dynamic>> fetchMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/$movieId?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'id': data['id'],
        'title': data['title'],
        'overview': data['overview'],
        'release_date': data['release_date'],
        'runtime': data['runtime'],
        'genres': data['genres'],
        'poster_path': data['poster_path'],
        'vote_average': data['vote_average'],
      };
    } else {
      throw Exception('Failed to load movie details');
    }
  }

  Future<Map<String, dynamic>> fetchTVDetails(int tvId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv/$tvId?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'id': data['id'],
        'name': data['name'],
        'overview': data['overview'],
        'first_air_date': data['first_air_date'],
        'episode_run_time': data['episode_run_time'],
        'genres': data['genres'],
        'poster_path': data['poster_path'],
        'vote_average': data['vote_average'],
      };
    } else {
      throw Exception('Failed to load TV series details');
    }
  }

  Future<List<dynamic>> fetchAllMovies({required int page}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/discover/movie?api_key=$apiKey&page=$page'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['results'];
    } else {
      throw Exception('Failed to load all movies');
    }
  }

  Future<String?> fetchTrailerUrl(int movieId, {required String type}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/$movieId/videos?api_key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final results = body['results'];

      if (results is List) {
        // Try to find the first YouTube trailer
        for (var video in results) {
          if (video['type'] == 'Trailer' && video['site'] == 'YouTube') {
            return video['key'];
          }
        }
      }
    }

    return null;
  }

  Future<List<dynamic>> fetchRelatedMovies(int movieId) async {
    try {
      final movieDetailsResponse = await http.get(
        Uri.parse('$baseUrl/movie/$movieId?api_key=$apiKey'),
      );
      if (movieDetailsResponse.statusCode != 200) {
        throw Exception('Failed to load movie details');
      }

      final movieDetails = jsonDecode(movieDetailsResponse.body);
      final String originalLanguage = movieDetails['original_language'];
      final genreIds = (movieDetails['genres'] as List)
          .map((genre) => genre['id'] as int)
          .toList();

      final relatedResponse = await http.get(
        Uri.parse('$baseUrl/movie/$movieId/similar?api_key=$apiKey'),
      );
      if (relatedResponse.statusCode != 200) {
        throw Exception('Failed to load similar movies');
      }

      final related = jsonDecode(relatedResponse.body)['results'] as List;
      return related.where((movie) {
        final langMatch = movie['original_language'] == originalLanguage;
        final genres = movie['genre_ids'] ?? [];
        final genreMatch = genres.any((id) => genreIds.contains(id));
        return langMatch || genreMatch;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch related movies: $e');
    }
  }

  Future<List<dynamic>> fetchRelatedTVSeries(int seriesId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv/$seriesId/similar?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['results'];
    } else {
      throw Exception('Failed to load related TV series');
    }
  }

  Future<String?> fetchTVTrailerUrl(int seriesId) async {
    final String url = '$baseUrl/tv/$seriesId/videos?api_key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final videos = jsonDecode(response.body)['results'] as List<dynamic>;

        if (videos.isEmpty) return null;

        // Filter only YouTube trailers
        final youtubeTrailers = videos.where((video) =>
        video['site'] == 'YouTube' &&
            video['type'] == 'Trailer').toList();

        // Priority 1: Official trailers with relevant names
        final prioritizedTrailer = youtubeTrailers.firstWhere(
              (video) =>
          (video['official'] == true) &&
              (video['name']?.toLowerCase().contains('official') ?? false) &&
              (video['name']?.toLowerCase().contains('season') ?? true),
          orElse: () => null,
        );

        if (prioritizedTrailer != null) return prioritizedTrailer['key'];

        // Priority 2: Any official YouTube trailer
        final officialFallback = youtubeTrailers.firstWhere(
              (video) => video['official'] == true,
          orElse: () => null,
        );
        if (officialFallback != null) return officialFallback['key'];

        // Priority 3: Any YouTube trailer at all
        if (youtubeTrailers.isNotEmpty) return youtubeTrailers.first['key'];
      }
    } catch (e) {
      debugPrint('Error fetching trailer: $e');
    }
    return null;
  }

  Future<List<dynamic>> fetchTrendingMoviesAndSeries() async {
    final url = Uri.parse('$baseUrl/trending/all/day?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results'];
    } else {
      throw Exception('Failed to load trending content');
    }
  }

  Future<List<dynamic>> fetchNewReleases() async {
    final response = await http.get(
      Uri.parse('$baseUrl/movie/now_playing?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['results'];
    } else {
      throw Exception('Failed to load new releases');
    }
  }

  Future<List<dynamic>> fetchPopularSeries() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tv/popular?api_key=$apiKey'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['results'];
    } else {
      throw Exception('Failed to load popular series');
    }
  }

  //Upcoming movies fetched from the TMDB
  Future<List<dynamic>> fetchUpcomingMovies() async {
    final today = DateTime.now();

    final url = Uri.parse(
        '$baseUrl/movie/upcoming'
            '?api_key=$apiKey'
            '&language=en-US'
            '&region=US' // use your target country
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> results = data['results'];

      print("🔎 Raw TMDB results count: ${results.length}");

      final List<dynamic> upcoming = results.where((movie) {
        final releaseDateStr = movie['release_date'];
        if (releaseDateStr == null || releaseDateStr.isEmpty) return false;

        try {
          final releaseDate = DateTime.parse(releaseDateStr);
          return releaseDate.isAfter(today.subtract(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();

      for (var movie in upcoming) {
        print("✅ Upcoming: ${movie['title']} — ${movie['release_date']}");
      }

      return upcoming;
    } else {
      print("❌ TMDB error: ${response.statusCode} ${response.body}");
      throw Exception('Failed to load upcoming movies');
    }
  }

  //Upcoming TV series fetched from the TMDB
  Future<List<dynamic>> fetchUpcomingSeries() async {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    final url = Uri.parse(
        '$baseUrl/discover/tv'
            '?api_key=$apiKey'
            '&language=en-US'
            '&sort_by=first_air_date.asc'
            '&first_air_date.gte=$todayStr'
            '&with_original_language=en'  // optional: limit to English shows
            '&region=US'                  // optional: target region
            '&include_null_first_air_dates=false'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> results = data['results'];

      print("📺 Raw TMDB TV results count: ${results.length}");

      final upcoming = results.where((series) {
        final dateStr = series['first_air_date'];
        if (dateStr == null || dateStr.isEmpty) return false;

        try {
          final airDate = DateTime.parse(dateStr);
          return airDate.isAfter(today.subtract(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();

      for (var series in upcoming) {
        print("✅ Upcoming Series: ${series['name']} — ${series['first_air_date']}");
      }

      return upcoming;
    } else {
      print("❌ TMDB error: ${response.statusCode} ${response.body}");
      throw Exception('Failed to load upcoming series');
    }
  }

}
