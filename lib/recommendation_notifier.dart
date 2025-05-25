import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RecommendationNotifier {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> checkRecommendedMovies({
    required String traktAccessToken,
    required String traktClientId,
    required String tmdbApiKey,
  }) async {
    await initNotifications();
    final prefs = await SharedPreferences.getInstance();
    final notifiedIds = prefs.getStringList('notified_recommendations') ?? [];

    print("✅ Fetching Trakt-based recommendations...");

    final movieRecs = await _fetchTraktRecommendations(traktAccessToken, traktClientId, type: 'movies');
    final showRecs = await _fetchTraktRecommendations(traktAccessToken, traktClientId, type: 'shows');
    final allRecs = [...movieRecs, ...showRecs];

    for (final item in allRecs) {
      final type = item.containsKey('movie') ? 'movie' : 'tv';
      final content = item[type];
      final tmdbId = content?['ids']?['tmdb']?.toString();
      final traktId = content?['ids']?['trakt']?.toString();
      final title = content?['title'] ?? 'Untitled';

      if (tmdbId == null || traktId == null || notifiedIds.contains(traktId)) continue;

      final releaseDate = await _getReleaseDate(tmdbId, tmdbApiKey, type);
      if (releaseDate != null) {
        final diff = releaseDate.difference(DateTime.now()).inDays;
        if (diff >= 0 && diff <= 3) {
          print("🎬 Releasing soon: $title on $releaseDate");
          await _notify(title, '"$title" (Trakt recommendation) releases on $releaseDate');
          notifiedIds.add(traktId);
          continue;
        }
      }

      final available = await _isAvailableToStream(tmdbId, tmdbApiKey, type);
      if (available != null && available.isNotEmpty) {
        print("📺 Now streaming: $title on $available");
        await _notify(title, '"$title" (Trakt recommendation) is now streaming on $available');
        notifiedIds.add(traktId);
      }
    }

    await prefs.setStringList('notified_recommendations', notifiedIds);
  }

  static Future<List<dynamic>> _fetchTraktRecommendations(
      String token,
      String clientId, {
        String type = 'movies',
      }) async {
    final url = Uri.parse('https://api.trakt.tv/recommendations/$type');
    final response = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'trakt-api-version': '2',
      'trakt-api-key': clientId,
    });

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }

    print("❌ Failed to fetch Trakt $type recommendations: ${response.statusCode}");
    return [];
  }

  static Future<DateTime?> _getReleaseDate(String tmdbId, String apiKey, String type) async {
    final url = Uri.parse('https://api.themoviedb.org/3/$type/$tmdbId?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final dateStr = type == 'movie' ? data['release_date'] : data['first_air_date'];
      if (dateStr != null && dateStr.isNotEmpty) {
        return DateTime.tryParse(dateStr);
      }
    }
    return null;
  }

  static Future<String?> _isAvailableToStream(String tmdbId, String apiKey, String type) async {
    final url = Uri.parse('https://api.themoviedb.org/3/$type/$tmdbId/watch/providers?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as Map<String, dynamic>;
      const regions = ['IN', 'US', 'GB', 'CA', 'DE'];

      for (final region in regions) {
        final entry = results[region];
        if (entry != null) {
          final platforms = entry['flatrate'];
          if (platforms != null && platforms is List && platforms.isNotEmpty) {
            final providerNames = platforms
                .map((p) => p['provider_name']?.toString())
                .whereType<String>()
                .toList()
                .join(', ');
            if (providerNames.isNotEmpty) {
              return "$providerNames (Region: $region)";
            }
          }
        }
      }
    }
    return null;
  }

  static Future<void> _notify(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'recommendation_channel',
      'Trakt Recommendations',
      channelDescription: 'Notifies you about recommended movies and shows',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      title.hashCode,
      '🎬 Recommendation: $title',
      body,
      notificationDetails,
    );
  }
}
