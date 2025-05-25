import 'dart:convert';
import 'package:http/http.dart' as http;

class JustWatchService {
  static const String _tmdbApiKey = 'e7afa1d9a7f465737e265fb314b7d391'; // Replace with your TMDb key
  static const String _baseTmdbUrl = 'https://api.themoviedb.org/3';

  /// Get watch providers for a movie using TMDb’s official endpoint
  static Future<List<Map<String, dynamic>>> getWatchProvidersForMovie({
    required int tmdbId,
    String region = 'US',
  }) async {
    final url = Uri.parse(
      'https://api.themoviedb.org/3/movie/$tmdbId/watch/providers?api_key=e7afa1d9a7f465737e265fb314b7d391',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    print('📶 TMDB API response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final regionData = data['results'][region];

      if (regionData != null && regionData['flatrate'] != null) {
        return List<Map<String, dynamic>>.from(regionData['flatrate']);
      }
    }
    return [];
  }

  /// Get watch providers for a TV series using TMDb’s official endpoint
  static Future<List<Map<String, dynamic>>> getWatchProvidersForSeries({
    required int tmdbId,
    String region = 'US',
  }) async {
    final url = Uri.parse(
      'https://api.themoviedb.org/3/tv/$tmdbId/watch/providers?api_key=$_tmdbApiKey',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    print('📶 TMDB Series API response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final regionData = data['results'][region];

      if (regionData != null && regionData['flatrate'] != null) {
        return List<Map<String, dynamic>>.from(regionData['flatrate']);
      }
    }
    return [];
  }

}