import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TraktAuth {
  static const String clientId = 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d';
  static const String clientSecret = '8f5796f429c6e68577e4f740eabf1f707f488f81de483ef16e2fff36357681a1';
  static const String traktApiBaseUrl = 'https://api.trakt.tv';
  static const String traktAuthUrl = 'https://api.trakt.tv/oauth/device/code';
  static const String traktTokenUrl = 'https://api.trakt.tv/oauth/device/token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();


  Future<Map<String, dynamic>> getDeviceCode() async {
    final response = await http.post(
      Uri.parse(traktAuthUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'client_id': clientId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch device code: ${response.body}');
    }
  }

  Future<Map<String, dynamic>?> tryGetAccessTokenOnce(String deviceCode) async {
    final response = await http.post(
      Uri.parse(traktTokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': deviceCode,
        'client_id': clientId,
        'client_secret': clientSecret,
      }),
    );

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      return jsonDecode(response.body);
    }

    return null;
  }

  // ----------------------- Device Auth -----------------------

  Future<bool> launchTraktLogin(BuildContext context) async {
    final deviceCodeResponse = await http.post(
      Uri.parse(traktAuthUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'client_id': clientId}),
    );

    if (deviceCodeResponse.statusCode != 200) {
      throw Exception('Failed to fetch device code');
    }

    final data = jsonDecode(deviceCodeResponse.body);
    final deviceCode = data['device_code'];
    final userCode = data['user_code'];
    final verificationUrl = data['verification_url'];

    //await Clipboard.setData(ClipboardData(text: userCode));

    bool success = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Authorize ScreenSaga'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Code copied to clipboard:\n\n$userCode\n\nTap below to open Trakt and enter the code.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await launchUrl(Uri.parse(verificationUrl), mode: LaunchMode.externalApplication);
            },
            child: const Text('Open Trakt'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final tokenResponse = await _tryGetTokenOnce(deviceCode);
                if (tokenResponse != null) {
                  await saveTokenData(tokenResponse);
                  success = true;
                }
              } catch (_) {}
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );

    return success;
  }

  Future<Map<String, dynamic>?> _tryGetTokenOnce(String deviceCode) async {
    final response = await http.post(
      Uri.parse(traktTokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': deviceCode,
        'client_id': clientId,
        'client_secret': clientSecret,
      }),
    );

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final data = jsonDecode(response.body);
      return data;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _pollForToken(String deviceCode, int interval) async {
    final url = Uri.parse(traktTokenUrl);
    int attempts = 0;
    const maxAttempts = 60;

    while (attempts < maxAttempts) {
      await Future.delayed(Duration(seconds: interval));

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': deviceCode,
          'client_id': clientId,
          'client_secret': clientSecret,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['access_token'] != null) {
        return data;
      }

      if (data['error'] == 'authorization_pending') {
        attempts++;
        continue;
      } else if (data['error'] == 'slow_down') {
        attempts++;
        await Future.delayed(const Duration(seconds: 5));
      } else {
        break;
      }
    }

    return null;
  }

  Future<void> saveTokenData(Map<String, dynamic> data) async {
    await _secureStorage.write(key: 'access_token', value: data['access_token']);
    await _secureStorage.write(key: 'refresh_token', value: data['refresh_token']);
    await _secureStorage.write(key: 'expires_in', value: data['expires_in'].toString());
    await _secureStorage.write(key: 'created_at', value: DateTime.now().millisecondsSinceEpoch.toString());
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<void> logout() async {
    await _secureStorage.deleteAll();
  }

  Future<void> clearAccessToken() async {
    await _secureStorage.delete(key: 'access_token');
  }

  // ----------------------- Token Validation -----------------------

  Future<String?> getValidAccessToken() async {
    await _refreshTokenIfNeeded();
    return await _secureStorage.read(key: 'access_token');
  }

  // ----------------------- Trakt Sync Actions for Movies -----------------------

  Future<void> likeMovie(int tmdbId) async {
    await _postToTrakt('/sync/likes', {
      "movies": [
        {
          "ids": {"tmdb": tmdbId}
        }
      ]
    });
  }

  Future<void> addToCollection(int tmdbId) async {
    await _postToTrakt('/sync/collection', {
      "movies": [
        {
          "ids": {"tmdb": tmdbId}
        }
      ]
    });
  }

  Future<void> addToWatchlist(int tmdbId) async {
    await _postToTrakt('/sync/watchlist', {
      "movies": [
        {
          "ids": {"tmdb": tmdbId}
        }
      ]
    });
  }

  Future<void> commentOnMovie(int tmdbId, String comment, {bool spoiler = false}) async {
    final token = await getValidAccessToken();
    if (token == null) throw Exception("User not logged in");

    final response = await http.post(
      Uri.parse('$traktApiBaseUrl/comments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'trakt-api-key': clientId,
        'trakt-api-version': '2',
      },
      body: jsonEncode({
        "comment": comment,
        "spoiler": spoiler,
        "movie": {"ids": {"tmdb": tmdbId}},
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to post comment: ${response.body}');
    }
  }

  // ----------------------- Trakt Sync Actions for Shows (Series) -----------------------

  Future<void> addShowToWatchlist(int tmdbId) async {
    await _postToTrakt('/sync/watchlist', {
      "shows": [
        {
          "ids": {"tmdb": tmdbId}
        }
      ]
    });
  }

  Future<void> removeShowFromWatchlist(int tmdbId) async {
    await _postToTrakt('/sync/watchlist/remove', {
      "shows": [
        {
          "ids": {"tmdb": tmdbId}
        }
      ]
    });
  }

  Future<void> addShowToCollection(int tmdbId) async {
    await _postToTrakt('/sync/collection', {
      "shows": [
        {
          "ids": {"tmdb": tmdbId}
        }
      ]
    });
  }

  Future<void> removeShowFromCollection(int tmdbId) async {
    await _postToTrakt('/sync/collection/remove', {
      "shows": [
        {
          "ids": {"tmdb": tmdbId}
        }
      ]
    });
  }

  Future<void> commentOnShow(int tmdbId, String comment, {bool spoiler = false}) async {
    final token = await getValidAccessToken();
    if (token == null) throw Exception("User not logged in");

    final response = await http.post(
      Uri.parse('$traktApiBaseUrl/comments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'trakt-api-key': clientId,
        'trakt-api-version': '2',
      },
      body: jsonEncode({
        "comment": comment,
        "spoiler": spoiler,
        "show": {"ids": {"tmdb": tmdbId}},
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to post comment: ${response.body}');
    }
  }

  // ----------------------- Private Helper -----------------------

  Future<void> _postToTrakt(String endpoint, Map<String, dynamic> body) async {
    final token = await getValidAccessToken();
    if (token == null) throw Exception("User not logged in");

    final response = await http.post(
      Uri.parse('$traktApiBaseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'trakt-api-key': clientId,
        'trakt-api-version': '2',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to sync with Trakt: ${response.body}');
    }
  }

  Future<bool> isSeriesInWatchlist(int tmdbId) async {
    final accessToken = await getValidAccessToken();
    if (accessToken == null) return false;

    final response = await http.get(
      Uri.parse('https://api.trakt.tv/sync/watchlist/shows'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': clientId,
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.any((item) => item['show']['ids']['tmdb'] == tmdbId);
    }
    return false;
  }

  Future<bool> isSeriesInCollection(int tmdbId) async {
    final accessToken = await getValidAccessToken();
    if (accessToken == null) return false;

    final response = await http.get(
      Uri.parse('https://api.trakt.tv/sync/collection/shows'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': clientId,
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.any((item) => item['show']['ids']['tmdb'] == tmdbId);
    }
    return false;
  }

  Future<void> _refreshTokenIfNeeded() async {
    final createdAtStr = await _secureStorage.read(key: 'created_at');
    final expiresInStr = await _secureStorage.read(key: 'expires_in');
    if (createdAtStr == null || expiresInStr == null) return;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(int.parse(createdAtStr));
    final expiresIn = Duration(seconds: int.parse(expiresInStr));
    final expiryTime = createdAt.add(expiresIn);
    final now = DateTime.now();

    if (now.isAfter(expiryTime)) {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) throw Exception("Refresh token missing");

      final response = await http.post(
        Uri.parse('https://api.trakt.tv/oauth/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refresh_token': refreshToken,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
          'grant_type': 'refresh_token',
        }),
      );

      if (response.statusCode == 200) {
        await saveTokenData(jsonDecode(response.body));
      } else {
        throw Exception("Failed to refresh token: ${response.body}");
      }
    }
  }
  // Add inside TraktAuth
  // ✅ Fetch movie watchlist
  Future<List<dynamic>> getMovieWatchlist() async {
    final accessToken = await getAccessToken();
    final response = await http.get(
      Uri.parse('https://api.trakt.tv/sync/watchlist/movies'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d', // replace this
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('❌ Failed to fetch movie watchlist: ${response.statusCode}');
      return [];
    }
  }

// ✅ Fetch show watchlist
  Future<List<dynamic>> getShowWatchlist() async {
    final accessToken = await getAccessToken();
    final response = await http.get(
      Uri.parse('https://api.trakt.tv/sync/watchlist/shows'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d', // replace this
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('❌ Failed to fetch show watchlist: ${response.statusCode}');
      return [];
    }
  }

  Future<String?> getUsernameFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenData = prefs.getString('trakt_token');
    if (tokenData != null) {
      final map = jsonDecode(tokenData);
      final res = await http.get(
        Uri.parse('https://api.trakt.tv/users/me'),
        headers: {
          'Authorization': 'Bearer ${map['access_token']}',
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': TraktAuth.clientId,
        },
      );
      if (res.statusCode == 200) {
        final userData = jsonDecode(res.body);
        return userData['username'];
      }
    }
    return null;
  }
}
