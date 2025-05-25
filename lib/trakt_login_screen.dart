import 'package:flutter/material.dart';
import 'trakt_auth.dart';

class TraktLoginScreen extends StatefulWidget {
  const TraktLoginScreen({super.key});

  @override
  State<TraktLoginScreen> createState() => _TraktLoginScreenState();
}

class _TraktLoginScreenState extends State<TraktLoginScreen> {
  final TraktAuth _traktAuth = TraktAuth();
  bool _isLoggingIn = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoggingIn = true);
    try {
      print("📤 Launching Trakt login...");
      await _traktAuth.launchTraktLogin(context); // Performs device code login

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Logged in successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Send 'success' back to login_screen
    } catch (e) {
      print("❌ Trakt login failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Login failed: $e"),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoggingIn = false); // Reset loading state
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login with Trakt')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Click the button below to log in to Trakt.\nYou'll be redirected automatically.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoggingIn ? null : _handleLogin,
                icon: _isLoggingIn
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.login),
                label: Text(_isLoggingIn ? "Logging in..." : "Login with Trakt"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
