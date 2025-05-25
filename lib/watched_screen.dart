import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'trakt_auth.dart';
import 'movie_details.dart';
import 'series_details.dart';

class TraktItem {
  final int tmdbId;
  final String title;
  final String mediaType;

  TraktItem(this.tmdbId, this.title, this.mediaType);
}

class WatchedScreen extends StatefulWidget {
  const WatchedScreen({Key? key}) : super(key: key);

  @override
  _WatchedScreenState createState() => _WatchedScreenState();
}

class _WatchedScreenState extends State<WatchedScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> movieItems = [];
  List<Map<String, dynamic>> seriesItems = [];
  bool isLoading = true;
  final String tmdbApiKey = 'e7afa1d9a7f465737e265fb314b7d391';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadWatched();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncAndUpdateWatched();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> syncAndUpdateWatched() async {
    setState(() => isLoading = true);
    await syncTraktWatchedToLocal();
    await loadWatched();
    if (mounted) setState(() => isLoading = false);
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
    final allItems = <String, Map<String, dynamic>>{};

    await Future.wait([
      fetchPaginated('movies', headers, allItems),
      fetchPaginated('shows', headers, allItems),
      fetchWatchedShows(headers, allItems),
    ]);

    final finalList = allItems.values.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('watched', finalList);
    print('✅ Synced ${finalList.length} watched items from Trakt');
  }

  Future<void> fetchPaginated(
      String type,
      Map<String, String> headers,
      Map<String, Map<String, dynamic>> allItems,
      ) async {
    int page = 1;
    bool done = false;
    const int maxPages = 20;

    while (!done && page <= maxPages) {
      final url = 'https://api.trakt.tv/sync/history/$type?page=$page&limit=100';
      print('📄 Fetching $type - page $page');

      try {
        final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          print('❌ Failed to fetch $type page $page: ${response.statusCode}');
          break;
        }

        final data = jsonDecode(response.body);
        if (data.isEmpty) break;

        print('✅ Fetched ${data.length} items for $type (Page $page)');

        List<TraktItem> itemsToProcess = [];
        List<Future<String?>> posterFutures = [];

        for (var item in data) {
          final content = item[type == 'movies' ? 'movie' : 'show'];
          final rawTmdbId = content?['ids']?['tmdb'];
          final fallbackId = content?['ids']?['trakt'];
          final title = content?['title'] ?? content?['show']?['title'];
          final mediaType = type == 'movies' ? 'movie' : 'show';

          int? tmdbId;
          if (rawTmdbId is int) {
            tmdbId = rawTmdbId;
          } else if (fallbackId != null) {
            tmdbId = int.tryParse(fallbackId.toString());
          }

          if (tmdbId == null || title == null) {
            print('⚠️ Skipping item (missing ID or title): ${content?['title']}');
            continue;
          }

          itemsToProcess.add(TraktItem(tmdbId, title, mediaType));
          posterFutures.add(fetchPosterPathFromTmdb(tmdbId, mediaType));
        }

        try {
          List<String?> posterPaths = await Future.wait(posterFutures);
          for (int i = 0; i < itemsToProcess.length; i++) {
            final item = itemsToProcess[i];
            final posterPath = posterPaths[i] ?? '';
            final key = '${item.tmdbId}_${item.mediaType}';
            allItems[key] = {
              'id': item.tmdbId,
              'title': item.title,
              'posterPath': posterPath,
              'type': item.mediaType,
            };
          }
        } catch (e) {
          print('⚠️ Error processing posters: $e');
        }

        if (data.length < 100) {
          print('✅ No more items on page $page. Done.');
          done = true;
        } else {
          page++;
        }
      } catch (e) {
        print('⛔ Timeout or error on page $page: $e');
        break;
      }
    }
  }

  Future<String?> fetchPosterPathFromTmdb(int tmdbId, String type) async {
    final cached = await getCachedPoster(tmdbId, type);
    if (cached != null) return cached;

    try {
      final endpoint = type == 'movie' ? 'movie' : 'tv';
      final response = await http.get(
        Uri.parse('https://api.themoviedb.org/3/$endpoint/$tmdbId?api_key=$tmdbApiKey&language=en-US'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final posterPath = data['poster_path'];
        await setCachedPoster(tmdbId, type, posterPath);
        return posterPath;
      }
    } catch (e) {
      print('❌ Poster fetch failed for TMDB ID $tmdbId: $e');
    }
    return null;
  }

  // Correct parameter name
  Future<String?> getCachedPoster(int tmdbId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$tmdbId ${type}_poster'; // ✅ Uses tmdbId (no underscore)
    return prefs.getString(key);
  }

  Future<void> setCachedPoster(int tmdbId, String type, String? posterPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$tmdbId ${type}_poster'; // ✅ Uses tmdbId (no underscore)
    await prefs.setString(key, posterPath ?? '');
  }

  Future<void> loadWatched() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('watched') ?? [];

    final uniqueMap = <String, Map<String, dynamic>>{};
    for (var item in saved) {
      final map = jsonDecode(item) as Map<String, dynamic>;
      final key = "${map['id']}_${map['type']}";
      uniqueMap[key] = map;
    }

    final allItems = uniqueMap.values.toList();
    movieItems = allItems.where((item) => item['type'] == 'movie').toList();
    seriesItems = allItems.where((item) => item['type'] == 'show').toList();
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

        return GestureDetector(
          onTap: () {
            final id = item['id'];
            if (isMovie) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailsScreen(movieId: id, movie: null)));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailsScreen(seriesId: id, series: null)));
            }
          },
          child: Card(
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
                item['title'] ?? item['name'] ?? 'No Title',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(width: 60, height: 90, color: Colors.white),
              title: Container(height: 20, color: Colors.white),
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
          title: const Text('Watched'),
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
              onPressed: syncAndUpdateWatched,
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

  Future<void> fetchWatchedShows(Map<String, String> headers, Map<String, Map<String, dynamic>> allItems) async {
    final url = 'https://api.trakt.tv/sync/watched/shows';
    print('📄 Fetching watched shows list');

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) {
        print('❌ Failed to fetch watched shows: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      List<TraktItem> itemsToProcess = [];
      List<Future<String?>> posterFutures = [];

      for (var show in data) {
        final showData = show['show'];
        final tmdbId = showData?['ids']?['tmdb'] ?? showData?['ids']?['trakt'];
        final title = showData?['title'];

        if (tmdbId == null || title == null) {
          print('⚠️ Skipping show with missing ID or title.');
          continue;
        }

        itemsToProcess.add(TraktItem(tmdbId, title, 'show'));
        posterFutures.add(fetchPosterPathFromTmdb(tmdbId, 'show'));
      }

      final posterPaths = await Future.wait(posterFutures);
      for (int i = 0; i < itemsToProcess.length; i++) {
        final item = itemsToProcess[i];
        final posterPath = posterPaths[i] ?? '';
        final key = '${item.tmdbId}_${item.mediaType}';
        allItems[key] = {
          'id': item.tmdbId,
          'title': item.title,
          'posterPath': posterPath,
          'type': item.mediaType,
        };
      }

      print('✅ Added ${itemsToProcess.length} watched shows');
    } catch (e) {
      print('⛔ Error fetching watched shows: $e');
    }
  }


}