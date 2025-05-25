import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseNotifier {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> checkUpcomingReleases(List<dynamic> traktWatchlist, String tmdbApiKey) async {
    await initNotifications();
    final prefs = await SharedPreferences.getInstance();
    final notifiedIds = prefs.getStringList('notified_upcoming') ?? [];

    for (var item in traktWatchlist) {
      try {
        final content = item['movie'] ?? item['show'];
        final ids = content?['ids'];
        final tmdbId = ids?['tmdb']?.toString();
        final traktId = ids?['trakt']?.toString();
        final title = content?['title'] ?? 'Untitled';
        final type = item.containsKey('movie') ? 'movie' : 'tv';

        if (tmdbId == null || traktId == null || notifiedIds.contains(traktId)) continue;

        final releaseDate = await _fetchReleaseDate(tmdbId, tmdbApiKey, type);
        if (releaseDate == null) continue;

        final now = DateTime.now();
        final diff = releaseDate.difference(now).inDays;

        if (diff >= 0 && diff <= 3) {
          await _showNotification(title, '🎬 $title releases on $releaseDate');
          notifiedIds.add(traktId);
        }
      } catch (e) {
        debugPrint('❌ Error checking upcoming release: $e');
      }
    }

    await prefs.setStringList('notified_upcoming', notifiedIds);
  }

  static Future<DateTime?> _fetchReleaseDate(String tmdbId, String apiKey, String type) async {
    final url = Uri.parse('https://api.themoviedb.org/3/$type/$tmdbId?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final dateStr = type == 'movie' ? data['release_date'] : data['first_air_date'];
      if (dateStr != null && dateStr.isNotEmpty) {
        return DateTime.tryParse(dateStr);
      }
    }
    return null;
  }

  static Future<void> checkStreamingAvailability(List<dynamic> traktWatchlist, String tmdbApiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedIds = prefs.getStringList('notified_available') ?? [];
    const regions = ['IN', 'US', 'GB', 'CA', 'DE'];

    for (var item in traktWatchlist) {
      try {
        final content = item['movie'] ?? item['show'];
        final ids = content?['ids'];
        final traktId = ids?['trakt']?.toString();
        final tmdbId = ids?['tmdb']?.toString();
        final title = content?['title'] ?? "Untitled";
        final type = item.containsKey('movie') ? 'movie' : 'tv';

        if (tmdbId == null || traktId == null || notifiedIds.contains(traktId)) continue;

        final url = Uri.parse('https://api.themoviedb.org/3/$type/$tmdbId/watch/providers?api_key=$tmdbApiKey');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as Map<String, dynamic>;

          for (final region in regions) {
            final entry = results[region];
            final platforms = entry?['flatrate'];
            if (platforms != null && platforms is List && platforms.isNotEmpty) {
              final providerNames = platforms
                  .map((p) => p['provider_name']?.toString())
                  .whereType<String>()
                  .toList()
                  .join(', ');

              if (providerNames.isNotEmpty) {
                await _showNotification(
                  title,
                  '📺 $title is now streaming in $region on $providerNames',
                );
                notifiedIds.add(traktId);
                break; // only notify once per item
              }
            }
          }
        }
      } catch (e) {
        debugPrint("❌ Error checking streaming availability: $e");
      }
    }

    await prefs.setStringList('notified_available', notifiedIds);
  }

  static Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'release_channel',
      'Release & Streaming Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      title.hashCode,
      title,
      body,
      notificationDetails,
    );
  }
}
