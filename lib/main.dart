import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'home_screen.dart';
import 'login_screen.dart';
import 'trakt_auth.dart';
import 'release_notifier.dart';
import 'recommendation_notifier.dart';
import 'theme_notifier.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeNotificationPermissions();

  // ✅ Only initialize Workmanager on Android and iOS
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    await Workmanager().registerPeriodicTask(
      "checkUpcomingReleasesTask",
      "checkUpcomingReleases",
      frequency: const Duration(hours: 24),
      initialDelay: const Duration(seconds: 30),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await Workmanager().registerPeriodicTask(
      "checkRecommendationsTask",
      "checkRecommendations",
      frequency: const Duration(hours: 24),
      initialDelay: const Duration(seconds: 30),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  runApp(const MyApp());
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final traktAccessToken = prefs.getString('trakt_access_token');
    final tmdbApiKey = prefs.getString('tmdb_api_key') ?? 'e7afa1d9a7f465737e265fb314b7d391';
    const traktClientId = 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d';

    try {
      final traktAuth = TraktAuth();

      if (task == "checkUpcomingReleases") {
        final movies = await traktAuth.getMovieWatchlist();
        final shows = await traktAuth.getShowWatchlist();
        final traktWatchlist = [...movies, ...shows];

        await ReleaseNotifier.checkStreamingAvailability(traktWatchlist, tmdbApiKey);
        await ReleaseNotifier.checkUpcomingReleases(traktWatchlist, tmdbApiKey);
      } else if (task == "checkRecommendations") {
        if (traktAccessToken != null) {
          await RecommendationNotifier.checkRecommendedMovies(
            traktAccessToken: traktAccessToken,
            traktClientId: traktClientId,
            tmdbApiKey: tmdbApiKey,
          );
        }
      }
    } catch (e) {
      print("Background task '$task' failed: $e");
    }

    return Future.value(true);
  });
}

Future<void> _initializeNotificationPermissions() async {
  final plugin = FlutterLocalNotificationsPlugin();

  final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission().catchError((_) {});

  final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  await ios?.requestPermissions(alert: true, badge: true, sound: true);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _isUserLoggedIn() async {
    final traktToken = await TraktAuth().getAccessToken();
    return traktToken != null && traktToken.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance().then((prefs) => prefs.getBool('isDarkTheme') ?? false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return ChangeNotifierProvider(
          create: (_) => ThemeNotifier(),
          child: Consumer<ThemeNotifier>(
            builder: (context, themeNotifier, _) {
              return MaterialApp(
                title: 'ScreenSaga',
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeMode: themeNotifier.themeMode, // <-- works now
                home: FutureBuilder<bool>(
                  future: _isUserLoggedIn(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    } else if (snapshot.data == true) {
                      return HomeScreenWithReleaseCheck();
                    } else {
                      return LoginScreen();
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class HomeScreenWithReleaseCheck extends StatefulWidget {
  @override
  State<HomeScreenWithReleaseCheck> createState() => _HomeScreenWithReleaseCheckState();
}

class _HomeScreenWithReleaseCheckState extends State<HomeScreenWithReleaseCheck> {
  late final StreamSubscription _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkReleases();
    _startConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      if (result is ConnectivityResult && result != ConnectivityResult.none) {
        await _checkReleases();
        await _checkRecommendations();
      } else if (result is List<ConnectivityResult> && result.any((r) => r != ConnectivityResult.none)) {
        await _checkReleases();
        await _checkRecommendations();
      }
    });
  }

  Future<void> _checkReleases() async {
    try {
      final traktAuth = TraktAuth();
      final movies = await traktAuth.getMovieWatchlist();
      final shows = await traktAuth.getShowWatchlist();
      final traktWatchlist = [...movies, ...shows];

      await ReleaseNotifier.checkStreamingAvailability(traktWatchlist, 'e7afa1d9a7f465737e265fb314b7d391');
      await ReleaseNotifier.checkUpcomingReleases(traktWatchlist, 'e7afa1d9a7f465737e265fb314b7d391');
    } catch (e) {
      print('Foreground release check failed: $e');
    }
  }

  Future<void> _checkRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final traktAccessToken = prefs.getString('trakt_access_token');
    const traktClientId = 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d';

    if (traktAccessToken != null) {
      await RecommendationNotifier.checkRecommendedMovies(
        traktAccessToken: traktAccessToken,
        traktClientId: traktClientId,
        tmdbApiKey: 'e7afa1d9a7f465737e265fb314b7d391',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: HomeScreen());
  }
}