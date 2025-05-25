import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'trakt_auth.dart';
import 'trakt_login_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TraktAuth _traktAuth = TraktAuth();
  String? _accessToken;
  String? _username;
  String? _avatarUrl;

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
      _fetchUserProfile(token);
    }
  }

  Future<void> _fetchUserProfile(String token) async {
    final response = await http.get(
      Uri.parse("https://api.trakt.tv/users/me"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
        "trakt-api-version": "2",
        "trakt-api-key": TraktAuth.clientId,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        _username = data['username'];
        _avatarUrl = data['images']?['avatar']?['full']; // Handle missing avatar
      });
    } else {
      print("Failed to fetch user profile: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with placeholder
              CircleAvatar(
                backgroundImage: _avatarUrl != null
                    ? NetworkImage(_avatarUrl!)
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
                radius: 50,
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 10),

              // Username with styling
              Text(
                _username ?? "Not Logged In",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 20),

              // Frosted glass effect card
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "Welcome to ScreenSaga!",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                      ),
                      onPressed: () {
                        if (_accessToken == null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TraktLoginScreen()),
                          ).then((_) => _checkLoginStatus());
                        } else {
                                 _traktAuth.logout().then((_) {
                            setState(() {
                              _accessToken = null;
                              _username = null;
                              _avatarUrl = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Logged out from Trakt")),
                            );
                          });
                        }
                      },
                      child: Text(_accessToken == null ? "Login to Trakt" : "Logout"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
