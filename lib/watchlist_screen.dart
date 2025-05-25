import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'trakt_auth.dart';
import 'movie_details.dart';
import 'series_details.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({Key? key}) : super(key: key);

  @override
  _WatchlistScreenState createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> movieItems = [];
  List<Map<String, dynamic>> seriesItems = [];
  bool isLoading = true;
  final String tmdbApiKey = 'e7afa1d9a7f465737e265fb314b7d391';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAndLoadWatchlist();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncAndLoadWatchlist() async {
    setState(() {
      isLoading = true;
    });

    await syncTraktWatchlistToLocal();
    await loadWatchlist();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> syncTraktWatchlistToLocal() async {
    final accessToken = await TraktAuth().getAccessToken();
    if (accessToken == null) return;

    final response = await http.get(
      Uri.parse('https://api.trakt.tv/sync/watchlist'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final prefs = await SharedPreferences.getInstance();
      List<Future<Map<String, dynamic>?>> futures = [];

      for (var item in data) {
        if (item['type'] != 'movie' && item['type'] != 'show') continue;

        final content = item[item['type']];
        final tmdbId = content['ids']['tmdb'];
        final title = content['title'];
        final type = item['type'];

        if (tmdbId == null) continue;

        futures.add(fetchItemWithPoster(tmdbId, title, type));
      }

      final fullWatchlist = (await Future.wait(futures))
          .where((item) => item != null)
          .map((item) => jsonEncode(item!))
          .toList();

      await prefs.setStringList('watchlist', fullWatchlist);
    }
  }

  Future<Map<String, dynamic>?> fetchItemWithPoster(int tmdbId, String title, String type) async {
    final posterPath = await fetchPosterPathFromTmdb(tmdbId, type);
    return {
      'id': tmdbId,
      'title': title,
      'posterPath': posterPath ?? '',
      'type': type,
    };
  }

  Future<void> loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWatchlist = prefs.getStringList('watchlist') ?? [];
    final allItems = savedWatchlist
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();

    movieItems = allItems.where((item) => item['type'] == 'movie').toList();
    seriesItems = allItems.where((item) => item['type'] == 'show').toList();
  }

  Future<String?> fetchPosterPathFromTmdb(int tmdbId, String type) async {
    try {
      final endpoint = type == 'movie' ? 'movie' : 'tv';
      final response = await http.get(
        Uri.parse('https://api.themoviedb.org/3/$endpoint/$tmdbId?api_key=$tmdbApiKey&language=en-US'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['poster_path'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> markAsWatched(int tmdbId, String type, String title, String? posterPath) async {
    final accessToken = await TraktAuth().getAccessToken();
    if (accessToken == null) return;

    final traktId = await getTraktIdFromTmdb(tmdbId, type);
    if (traktId == null) return;

    final body = {
      if (type == 'movie') 'movies': [{'ids': {'trakt': traktId}}],
      if (type == 'show') 'shows': [{'ids': {'trakt': traktId}}],
    };

    await http.post(
      Uri.parse('https://api.trakt.tv/sync/history'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
      },
      body: jsonEncode(body),
    );
  }

  Future<void> removeFromTraktWatchlist(int tmdbId, String type) async {
    final accessToken = await TraktAuth().getAccessToken();
    if (accessToken == null) {
      print('❌ No Trakt access token');
      return;
    }

    final traktId = await getTraktIdFromTmdb(tmdbId, type);
    if (traktId == null) {
      print('❌ Could not get Trakt ID for TMDB ID $tmdbId');
      return;
    }

    final body = {
      if (type == 'movie') 'movies': [{'ids': {'trakt': traktId}}],
      if (type == 'show') 'shows': [{'ids': {'trakt': traktId}}],
    };

    final response = await http.post(
      Uri.parse('https://api.trakt.tv/sync/watchlist/remove'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      print('✅ Removed from Trakt watchlist');
    } else {
      print('❌ Failed to remove from Trakt watchlist: ${response.statusCode}');
      print('📦 Trakt response: ${response.body}');
    }
  }

  Future<int?> getTraktIdFromTmdb(int tmdbId, String type) async {
    final endpoint = type == 'movie' ? 'movie' : 'show';
    try {
      final response = await http.get(
        Uri.parse('https://api.trakt.tv/search/tmdb/$tmdbId?type=$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
        },
      );

      print('📡 Trakt Lookup Status: ${response.statusCode}');
      print('📦 Trakt Lookup Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final content = data[0][type]; // 'movie' or 'show'
          final traktId = content?['ids']?['trakt'];
          if (traktId != null) {
            return traktId;
          }
        }
      }
    } catch (e) {
      print('❌ Exception during Trakt ID fetch: $e');
    }

    return null;
  }


  Widget buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No items'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final posterPath = item['posterPath'];
        final isMovie = item['type'] == 'movie';
        final id = item['id'];
        final type = item['type'];
        final title = item['title'];

        return Dismissible(
          key: ValueKey('$id$type'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.green,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Icon(Icons.check, color: Colors.black, size: 24),
                SizedBox(width: 8),
                Text(
                  'Watched',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          onDismissed: (_) async {
            final accessToken = await TraktAuth().getAccessToken();
            if (accessToken == null) return;

            final traktId = await getTraktIdFromTmdb(id, type);
            if (traktId == null) return;

            final headers = {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'trakt-api-version': '2',
              'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
            };

            Map<String, dynamic> watchedBody;

            if (type == 'movie') {
              watchedBody = {
                'movies': [
                  {'ids': {'trakt': traktId}}
                ]
              };
            } else {
              // Series - fetch episodes of season 1 from TMDB
              final episodes = await getEpisodesForSeason(id, 1);
              if (episodes.isEmpty) {
                print('⚠️ No episodes found for season 1. Skipping.');
                return;
              }

              watchedBody = {
                'shows': [
                  {
                    'ids': {'trakt': traktId},
                    'seasons': [
                      {
                        'number': 1,
                        'episodes': episodes.map((e) => {'number': e}).toList()
                      }
                    ]
                  }
                ]
              };
            }

            final removeBody = {
              type == 'movie' ? 'movies' : 'shows': [
                {'ids': {'trakt': traktId}}
              ]
            };

            final watchedResponse = await http.post(
              Uri.parse('https://api.trakt.tv/sync/history'),
              headers: headers,
              body: jsonEncode(watchedBody),
            );

            final removeResponse = await http.post(
              Uri.parse('https://api.trakt.tv/sync/watchlist/remove'),
              headers: headers,
              body: jsonEncode(removeBody),
            );

            if ((watchedResponse.statusCode == 201 || watchedResponse.statusCode == 200) &&
                (removeResponse.statusCode == 200 || removeResponse.statusCode == 204)) {
              final prefs = await SharedPreferences.getInstance();

              final savedWatchlist = prefs.getStringList('watchlist') ?? [];
              savedWatchlist.removeWhere((e) {
                final decoded = jsonDecode(e);
                return decoded['id'] == id && decoded['type'] == type;
              });
              await prefs.setStringList('watchlist', savedWatchlist);

              final savedWatched = prefs.getStringList('watched') ?? [];
              savedWatched.removeWhere((e) {
                final decoded = jsonDecode(e);
                return decoded['id'] == id && decoded['type'] == type;
              });
              savedWatched.add(jsonEncode(item));
              await prefs.setStringList('watched', savedWatched);

              await syncTraktWatchlistToLocal();
              await syncTraktWatchedToLocal();

              setState(() {
                items.removeAt(index);
              });

              print('✅ Synced and updated successfully to Trakt and local');
            } else {
              print('❌ Failed to sync with Trakt');
              print('Watched: ${watchedResponse.statusCode}');
              print('Remove: ${removeResponse.statusCode}');
              print('Response: ${watchedResponse.body}');
            }
          },
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => isMovie
                      ? MovieDetailsScreen(movieId: id, movie: null)
                      : SeriesDetailsScreen(seriesId: id, series: null),
                ),
              );
            },
            child: Card(
              color: Theme.of(context).cardColor, // Use theme-adaptive background color
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: (posterPath != null && posterPath.isNotEmpty)
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://image.tmdb.org/t/p/w500$posterPath',
                    width: 60,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                )
                    : const Icon(Icons.movie, size: 50),
                title: Text(
                  title ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<int>> getEpisodesForSeason(int tmdbId, int seasonNumber) async {
    final url = 'https://api.themoviedb.org/3/tv/$tmdbId/season/$seasonNumber?api_key=e7afa1d9a7f465737e265fb314b7d391&language=en-US';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final episodes = data['episodes'] as List<dynamic>;
        return episodes.map<int>((e) => e['episode_number'] as int).toList();
      }
    } catch (e) {
      print('❌ Error fetching episodes: $e');
    }
    return [];
  }

  Future<void> syncTraktWatchedToLocal() async {
    final accessToken = await TraktAuth().getAccessToken();
    if (accessToken == null) return;

    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'trakt-api-version': '2',
      'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
    };

    final prefs = await SharedPreferences.getInstance();
    final allItems = <String, Map<String, dynamic>>{}; // key = id_type

    Future<void> fetchPaginated(String type) async {
      int page = 1;
      bool done = false;

      while (!done) {
        final url = 'https://api.trakt.tv/sync/history/$type?page=$page&limit=100';
        final response = await http.get(Uri.parse(url), headers: headers);

        if (response.statusCode != 200) {
          print('❌ Failed to fetch $type history: ${response.statusCode}');
          break;
        }

        final data = jsonDecode(response.body);
        if (data.isEmpty) break;

        for (var item in data) {
          final content = item[type == 'movies' ? 'movie' : 'show'];
          final tmdbId = content?['ids']?['tmdb'];
          final title = content?['title'];
          final mediaType = type == 'movies' ? 'movie' : 'show';

          if (tmdbId == null || title == null) continue;

          final posterPath = await fetchPosterPathFromTmdb(tmdbId, mediaType);
          final key = '${tmdbId}_$mediaType';

          allItems[key] = {
            'id': tmdbId,
            'title': title,
            'posterPath': posterPath ?? '',
            'type': mediaType,
          };
        }

        if (data.length < 100) {
          done = true;
        } else {
          page++;
        }
      }
    }

    await fetchPaginated('movies');
    await fetchPaginated('shows');

    final finalList = allItems.values.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('watched', finalList);

    print('✅ Synced ${finalList.length} total watched items to local');
  }




  Widget buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(width: 60, height: 90, color: Theme.of(context).colorScheme.surface),
              title: Container(height: 20, color: Theme.of(context).colorScheme.surface),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFf8f9fa), Color(0xFFe0e0e0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('My Watchlist'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Movies'),
              Tab(text: 'Series'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _syncAndLoadWatchlist,
            )
          ],
        ),
        body: isLoading
            ? buildShimmerList()
            : TabBarView(
          controller: _tabController,
          children: [
            buildList(movieItems),
            buildList(seriesItems),
          ],
        ),
      ),
    );
  }
}