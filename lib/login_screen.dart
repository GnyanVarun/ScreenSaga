import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'trakt_auth.dart';
import 'home_screen.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoggingIn = false;
  String? _userCode;
  String _message = 'Sign in or sign up with Trakt to continue.';

  Future<void> _startTraktLogin() async {
    setState(() {
      _isLoggingIn = true;
      _message = 'Generating Trakt login session...';
    });

    try {
      final auth = TraktAuth();
      final deviceCodeResponse = await http.post(
        Uri.parse(TraktAuth.traktAuthUrl),
        headers: {'Content-Type': 'application/json'},
        body: const JsonEncoder().convert({'client_id': TraktAuth.clientId}),
      );

      if (deviceCodeResponse.statusCode != 200) {
        throw Exception('Failed to fetch device code');
      }

      final data = Map<String, dynamic>.from(jsonDecode(deviceCodeResponse.body));
      final deviceCode = data['device_code'];
      final userCode = data['user_code'];
      final verificationUrl = data['verification_url'];

      _userCode = userCode;
      await Clipboard.setData(ClipboardData(text: _userCode!));

      setState(() {
        _message = 'We’ve copied the code for you. Tap below to open Trakt and sign in.';
        _isLoggingIn = false;
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Authorize ScreenSaga'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter this code in Trakt:\n'),
              SelectableText(
                _userCode ?? '',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('(Code copied to clipboard)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await launchUrl(
                  Uri.parse(verificationUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Open Trakt'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // close dialog
                setState(() => _isLoggingIn = true);
                try {
                  final tokenResponse = await auth.tryGetAccessTokenOnce(deviceCode);
                  if (tokenResponse != null) {
                    await auth.saveTokenData(tokenResponse);
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  } else {
                    setState(() {
                      _isLoggingIn = false;
                      _message = 'Failed to log in. Please try again.';
                    });
                  }
                } catch (e) {
                  setState(() {
                    _isLoggingIn = false;
                    _message = 'Login failed: ${e.toString()}';
                  });
                }
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoggingIn = false;
        _message = 'Login failed: ${e.toString()}';
      });
    }
  }

  Widget _buildLoginButton() {
    return ElevatedButton.icon(
      onPressed: _isLoggingIn ? null : _startTraktLogin,
      icon: const Icon(Icons.login_rounded, color: Colors.white),
      label: _isLoggingIn
          ? const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : const Text("Login with Trakt"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent.shade700,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF23232F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tv, size: 60, color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  "Welcome to ScreenSaga",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  _message,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildLoginButton(),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://trakt.tv/join'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text(
                    "New to Trakt? Create an account",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}