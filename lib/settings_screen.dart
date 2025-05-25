import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'theme_notifier.dart';
import 'trakt_auth.dart';
import 'trakt_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TraktAuth _traktAuth = TraktAuth();
  String? _accessToken;
  String? _displayName;
  String? _about;
  String? _avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    String? token = await _traktAuth.getAccessToken();
    setState(() {
      _accessToken = token;
    });
    if (token != null) {
      await fetchUserProfile();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchUserProfile() async {
    final accessToken = await _traktAuth.getAccessToken();

    final response = await http.get(
      Uri.parse('https://api.trakt.tv/users/me?extended=full'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _displayName = data['name'] ?? '';
        _about = data['about'] ?? '';
        _avatarUrl = data['images']?['avatar']?['full'];
        _isLoading = false;
      });
    } else {
      print('❌ Failed to load profile: ${response.statusCode}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _traktAuth.clearAccessToken();
    setState(() {
      _accessToken = null;
      _displayName = null;
      _about = null;
      _avatarUrl = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logged out from Trakt")),
    );
  }

  Future<void> _clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Local data cleared.")),
    );
  }

  Widget _buildProfileSection() {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Container(width: 120, height: 20, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Container(width: 200, height: 14, color: Colors.grey.shade300),
          ],
        ),
      );
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade300,
          child: ClipOval(
            child: _avatarUrl != null
                ? Image.network(
              _avatarUrl!,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/logos/default_avatar.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                );
              },
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const CircularProgressIndicator();
              },
            )
                : Image.asset(
              'assets/default_avatar.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_displayName != null && _displayName!.isNotEmpty)
          Text(
            _displayName!,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        if (_about != null && _about!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 8.0),
            child: Text(
              _about!,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            if (_accessToken == null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TraktLoginScreen()),
              ).then((_) => _checkLoginStatus());
            } else {
              _logout();
            }
          },
          child: Text(
            _accessToken == null ? "Login to Trakt" : "Logout",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          Center(child: _buildProfileSection()),
          const SizedBox(height: 30),
          const Divider(),
          ListTile(
            title: const Text("Dark Theme"),
            trailing: Switch(
              value: themeNotifier.isDarkTheme,
              activeColor: Theme.of(context).colorScheme.secondary,
              inactiveTrackColor: Theme.of(context).disabledColor.withOpacity(0.4),
              onChanged: (val) {
                themeNotifier.toggleTheme(val);
              },
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: ElevatedButton.icon(
              onPressed: _clearLocalData,
              icon: const Icon(Icons.delete),
              label: const Text("Clear Local Data"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            title: const Text("About"),
            subtitle: const Text("ScreenSaga v1.0.0\nA cinematic companion app."),
            leading: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }
}
