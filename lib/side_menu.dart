import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'trakt_auth.dart';

class SideMenu extends StatefulWidget {
  final Function(String) onItemSelected;

  const SideMenu({Key? key, required this.onItemSelected}) : super(key: key);

  @override
  _SideMenuState createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  final TraktAuth _traktAuth = TraktAuth();
  String? _accessToken;
  String? _displayName;
  String? _avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    String? token = await _traktAuth.getAccessToken();
    setState(() => _accessToken = token);
    if (token != null) {
      final response = await http.get(
        Uri.parse('https://api.trakt.tv/users/me?extended=full'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _displayName = data['name'];
          _avatarUrl = data['images']?['avatar']?['full'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDrawerHeader({required Color color}) {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade700,
        highlightColor: Colors.grey.shade500,
        child: UserAccountsDrawerHeader(
          accountName: Container(width: 100, height: 16, color: Colors.grey),
          accountEmail: Container(width: 150, height: 14, color: Colors.grey),
          currentAccountPicture: CircleAvatar(backgroundColor: Colors.grey),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      );
    }

    return UserAccountsDrawerHeader(
      accountName: Text(
        _displayName ?? "Guest",
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      accountEmail: _accessToken != null ? const Text("Connected to Trakt") : const Text("Not connected"),
      currentAccountPicture: CircleAvatar(
        backgroundImage: _avatarUrl != null
            ? NetworkImage(_avatarUrl!)
            : const AssetImage('assets/default_avatar.png') as ImageProvider,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black.withOpacity(0.9),
      child: Column(
        children: [
          _buildDrawerHeader(color: Colors.white),
          _buildMenuItem("Trending", Icons.local_fire_department, context),
          _buildMenuItem("Watched", Icons.check_sharp, context),
          _buildMenuItem("Watchlist", Icons.bookmark, context),
          _buildMenuItem("Collection", Icons.video_library, context),
          const Divider(color: Colors.grey),
          _buildMenuItem("Settings", Icons.settings, context),
         // _buildMenuItem("Logout", Icons.exit_to_app, context),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        widget.onItemSelected(title);
      },
    );
  }
}
