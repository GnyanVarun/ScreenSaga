import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'trakt_auth.dart';
import 'movie_details.dart';
import 'series_details.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({Key? key}) : super(key: key);

  @override
  _CollectionScreenState createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> with SingleTickerProviderStateMixin {
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
      _syncAndLoadCollection();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncAndLoadCollection() async {
    setState(() {
      isLoading = true;
    });

    await syncTraktCollectionToLocal();
    await loadCollection();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> syncTraktCollectionToLocal() async {
    final accessToken = await TraktAuth().getAccessToken();
    if (accessToken == null) {
      print('❌ No access token available.');
      return;
    }

    print('🔄 Syncing Trakt Collection (movies + shows)...');

    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'trakt-api-version': '2',
      'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
    };

    final movieResponse = await http.get(
      Uri.parse('https://api.trakt.tv/sync/collection/movies'),
      headers: headers,
    );

    final showResponse = await http.get(
      Uri.parse('https://api.trakt.tv/sync/collection/shows'),
      headers: headers,
    );

    if (movieResponse.statusCode != 200 || showResponse.statusCode != 200) {
      print('❌ Failed: movies(${movieResponse.statusCode}), shows(${showResponse.statusCode})');
      return;
    }

    final movieData = jsonDecode(movieResponse.body);
    final showData = jsonDecode(showResponse.body);
    final prefs = await SharedPreferences.getInstance();
    List<Future<Map<String, dynamic>?>> futures = [];

    for (var item in movieData) {
      final content = item['movie'];
      final tmdbId = content['ids']['tmdb'];
      final title = content['title'];
      if (tmdbId == null || title == null) continue;

      print('🎬 Found movie: $title');
      futures.add(fetchItemWithPoster(tmdbId, title, 'movie'));
    }

    for (var item in showData) {
      final content = item['show'];
      final tmdbId = content['ids']['tmdb'];
      final title = content['title'];
      if (tmdbId == null || title == null) continue;

      print('📺 Found show: $title');
      futures.add(fetchItemWithPoster(tmdbId, title, 'show'));
    }

    final fullCollection = (await Future.wait(futures))
        .where((item) => item != null)
        .map((item) => jsonEncode(item!))
        .toList();

    print('💾 Saving ${fullCollection.length} items to SharedPreferences...');
    await prefs.setStringList('collection', fullCollection);
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

  Future<void> loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCollection = prefs.getStringList('collection') ?? [];

    final allItems = savedCollection
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
      } else {
        print('Failed to fetch poster for TMDB ID $tmdbId: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching poster path: $e');
      return null;
    }
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
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

  Widget buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No items'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final posterPath = item['posterPath'];
        final isMovie = item['type'] == 'movie';
        final id = item['id'];

        return GestureDetector(
          onTap: () {
            if (isMovie) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieDetailsScreen(movieId: id, movie: movieItems,),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SeriesDetailsScreen(seriesId: id, series: seriesItems,),
                ),
              );
            }
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
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
          title: const Text('My Collection'),
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
              onPressed: _syncAndLoadCollection,
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
