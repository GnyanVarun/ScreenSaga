// trakt_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TraktService {
  final String clientId = "a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d";
  final String clientSecret = "8f5796f429c6e68577e4f740eabf1f707f488f81de483ef16e2fff36357681a1"; // 👈 Add your secret here
  final String baseUrl = "https://api.trakt.tv";
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  /// 🔐 Authenticate using Trakt's Device Code Flow
  Future<void> authenticateWithDeviceCode() async {
    final response = await http.post(
      Uri.parse('$baseUrl/oauth/device/code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'client_id': clientId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final deviceCode = data['device_code'];
      final userCode = data['user_code'];
      final verificationUrl = data['verification_url'];
      final interval = data['interval'];

      print('🚀 Go to $verificationUrl and enter code: $userCode');

      // Poll for token
      while (true) {
        await Future.delayed(Duration(seconds: interval));

        final tokenResponse = await http.post(
          Uri.parse('$baseUrl/oauth/device/token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': deviceCode,
            'client_id': clientId,
            'client_secret': clientSecret,
          }),
        );

        if (tokenResponse.statusCode == 200) {
          final tokenData = jsonDecode(tokenResponse.body);
          await storage.write(key: 'access_token', value: tokenData['access_token']);
          await storage.write(key: 'refresh_token', value: tokenData['refresh_token']);
          print('✅ Trakt authentication successful!');
          break;
        } else if (tokenResponse.statusCode == 400) {
          print('⏳ Waiting for user to authorize...');
        } else {
          print('❌ Error: ${tokenResponse.body}');
          break;
        }
      }
    } else {
      print('❌ Failed to initiate device code flow: ${response.body}');
    }
  }

  /// 🔹 Retrieve Stored Access Token
  Future<String?> getAccessToken() async {
    return await storage.read(key: 'access_token');
  }

  /// ✅ Fetch Watchlist (Movies & TV Shows)
  Future<List<dynamic>> fetchWatchlist(String mediaType) async {
    String? accessToken = await getAccessToken();
    if (accessToken == null) throw 'No access token found';

    final response = await http.get(
      Uri.parse('$baseUrl/sync/watchlist/$mediaType'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'trakt-api-version': '2',
        'trakt-api-key': clientId,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw '❌ Failed to fetch watchlist: ${response.body}';
    }
  }

  /// ✅ Fetch Watch History (Movies & TV Shows)
  Future<List<dynamic>> fetchWatchHistory(String mediaType) async {
    String? accessToken = await getAccessToken();
    if (accessToken == null) throw 'No access token found';

    final response = await http.get(
      Uri.parse('$baseUrl/sync/history/$mediaType'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'trakt-api-version': '2',
        'trakt-api-key': clientId,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw '❌ Failed to fetch watch history: ${response.body}';
    }
  }
}
