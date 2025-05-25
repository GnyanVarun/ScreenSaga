import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'movie_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'trakt_auth.dart';
import 'comments_screen.dart';
import'streaming_providers_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  final int movieId;
  const MovieDetailsScreen({super.key, required this.movieId, required movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  late Future<dynamic> movieDetails;
  final TraktAuth traktAuth = TraktAuth();

  @override
  void initState() {
    super.initState();
    syncTraktWatchlistToLocal();  // 🔁 Syncs watchlist from Trakt
    syncTraktCollectionToLocal(); // ✅ Syncs collection from Trakt
    movieDetails = ApiService().fetchMovieDetails(widget.movieId);
  }

  Widget shimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade600,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 200,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 24, width: 200, color: Colors.grey),
            const SizedBox(height: 8),
            Container(height: 80, width: double.infinity, color: Colors.grey),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: List.generate(3, (index) => Container(
                width: 80,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
              )),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) => Container(
                width: 100,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
              )),
            ),
            const SizedBox(height: 24),
            Container(height: 20, width: 150, color: Colors.grey),
            const SizedBox(height: 8),
            Container(height: 150, width: double.infinity, color: Colors.grey),
          ],
        ),
      ),
    );
  }

//LOCAL SAVE MECHANISM FOR ADD TO WATCHLIST
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

        // 🛠 Instead of waiting immediately, start fetching poster in background
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


  Future<String?> fetchPosterPathFromTmdb(int tmdbId, String type) async {
    final endpoint = type == 'movie' ? 'movie' : 'tv';
    final response = await http.get(
      Uri.parse('https://api.themoviedb.org/3/$endpoint/$tmdbId?api_key=e7afa1d9a7f465737e265fb314b7d391&language=en-US'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['poster_path'];
    } else {
      return null;
    }
  }

  Future<bool> checkIfInWatchlist(int tmdbId) async {
    final accessToken = await traktAuth.getAccessToken();
    if (accessToken == null) return false;

    final response = await http.get(
      Uri.parse('https://api.trakt.tv/sync/watchlist/movies'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data.any((item) => item['movie']['ids']['tmdb'] == tmdbId);
    }

    return false;
  }

  Future<bool> checkIfInCollection(int tmdbId) async {
    final accessToken = await traktAuth.getAccessToken();
    if (accessToken == null) return false;

    final response = await http.get(
      Uri.parse('https://api.trakt.tv/sync/collection/movies'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data.any((item) => item['movie']['ids']['tmdb'] == tmdbId);
    }

    return false;
  }



//LOCAL SAVE MECHANISM FOR COLLECTION
  Future<void> syncTraktCollectionToLocal() async {
    final accessToken = await TraktAuth().getAccessToken();
    if (accessToken == null) return;

    final response = await http.get(
      Uri.parse('https://api.trakt.tv/sync/collection'),
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

      final fullCollection = (await Future.wait(futures))
          .where((item) => item != null)
          .map((item) => jsonEncode(item!))
          .toList();

      await prefs.setStringList('collection', fullCollection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Details'),
      ),
      body: FutureBuilder<dynamic>(
        future: movieDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load movie details.'));
          } else {
            final movie = snapshot.data;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PosterAndTitleWidget(
                    movie: movie,
                    onWatchlistToggle:_handleWatchlistToggle,
                    onCollectionToggle: _handleCollectionToggle,
                    onComment: _handleComments,
                    onSave: _handleSave,
                    onWhereToWatch: _handleWhereToWatch, //onCollectionToggle: (BuildContext , int , bool ) {  },
                  ),
                  OverviewWidget(movie: movie),
                  GenresWidget(genres: movie['genres'] ?? []),
                  RuntimeReleaseWidget(
                    runtime: movie['runtime'],
                    releaseDate: movie['release_date'],
                  ),
                  CastSectionWidget(movieId: movie['id']),
                  RelatedMoviesWidget(movieId: movie['id']),
                ],
              ),
            );
          }
        },
      ),
    );
  }

//SYNC OF TRAKT ID TO TMDB ID
  Future<int?> getTraktIdFromTmdb(int tmdbId) async {
    final accessToken = await traktAuth.getAccessToken(); // Or null if not required
    final response = await http.get(
      Uri.parse('https://api.trakt.tv/search/tmdb/$tmdbId?type=movie'),
      headers: {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data != null && data.isNotEmpty) {
        return data[0]['movie']['ids']['trakt'];
      }
    }
    return null;
  }

//WATCHLIST BUTTON MECHANISM
  void _handleWatchlistToggle(BuildContext context, int tmdbId, bool add) async {
    try {
      final traktId = await getTraktIdFromTmdb(tmdbId);
      if (traktId == null) {
        throw Exception('Failed to fetch Trakt ID from TMDB ID');
      }

      final accessToken = await traktAuth.getAccessToken();
      if (accessToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to Trakt.')),
        );
        return;
      }

      final url = add
          ? 'https://api.trakt.tv/sync/watchlist'
          : 'https://api.trakt.tv/sync/watchlist/remove';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
        },
        body: jsonEncode({
          "movies": [
            {
              "ids": {"trakt": traktId}
            }
          ]
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to ${add ? 'add to' : 'remove from'} watchlist: ${response.body}');
      }
      await syncTraktWatchlistToLocal();//SYNC ACROSS DEVICES FUNCTIONALITY FOR WATCHLIST
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('watchlisted_movies') ?? [];

      if (add) {
        if (!list.contains(tmdbId.toString())) list.add(tmdbId.toString());
      } else {
        list.remove(tmdbId.toString());
      }

      await prefs.setStringList('watchlisted_movies', list);

      // Save full movie details into SharedPreferences
      List<String> savedWatchlist = prefs.getStringList('watchlist') ?? [];

      if (add) {
        Map<String, dynamic> movieData = {
          'id': tmdbId,
          'title': (await movieDetails)['title'] ?? '',
          'posterPath': (await movieDetails)['poster_path'] ?? '',
          'type': 'movie',
        };

        bool alreadyExists = savedWatchlist.any((item) {
          final decoded = jsonDecode(item);
          return decoded['id'] == tmdbId && decoded['type'] == 'movie';
        });

        if (!alreadyExists) {
          savedWatchlist.add(jsonEncode(movieData));
        }
      } else {
        savedWatchlist.removeWhere((item) {
          final decoded = jsonDecode(item);
          return decoded['id'] == tmdbId && decoded['type'] == 'movie';
        });
      }
      await prefs.setStringList('watchlist', savedWatchlist);


      await prefs.setStringList('watchlist', savedWatchlist);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(add ? 'Added to Watchlist' : 'Removed from Watchlist')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Watchlist sync failed: $e')),
      );
    }
  }

  //SAVE BUTTON MECHANISM
  Future<void> _handleSave(BuildContext context, int tmdbId) async {
    try {
      final traktId = await getTraktIdFromTmdb(tmdbId);
      if (traktId == null) {
        throw Exception('Failed to fetch Trakt ID from TMDB ID');
      }

      final accessToken = await traktAuth.getAccessToken();
      if (accessToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to Trakt.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('https://api.trakt.tv/sync/collection'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
        },
        body: jsonEncode({
          "movies": [
            {
              "ids": {
                "trakt": traktId
              }
            }
          ]
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to save to collection: ${response.body}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your Trakt Collection!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save to collection: $e')),
      );
    }
  }
  Future<void> _handleCollectionToggle(BuildContext context, int tmdbId, bool add) async {
    try {
      final traktId = await getTraktIdFromTmdb(tmdbId);
      if (traktId == null) {
        throw Exception('Failed to fetch Trakt ID from TMDB ID');
      }

      final accessToken = await traktAuth.getAccessToken();
      if (accessToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to Trakt.')),
        );
        return;
      }

      final url = add
          ? 'https://api.trakt.tv/sync/collection'
          : 'https://api.trakt.tv/sync/collection/remove';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
        },
        body: jsonEncode({
          "movies": [
            {
              "ids": {"trakt": traktId}
            }
          ]
        }),
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to ${add ? 'add to' : 'remove from'} collection: ${response.body}');
      }

      await syncTraktCollectionToLocal();//SYNC ACROSS DEVICES FUNCTIONALITY FOR COLLECTION
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('saved_collection_movies') ?? [];

      if (add) {
        if (!list.contains(tmdbId.toString())) list.add(tmdbId.toString());
      } else {
        list.remove(tmdbId.toString());
      }

      await prefs.setStringList('saved_collection_movies', list);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(add ? 'Saved to Collection' : 'Removed from Collection')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collection sync failed: $e')),
      );
    }
  }

  //COMMENTS BUTTON MECHANISM
  void _handleComments(BuildContext context, int movieId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsScreen(movieId: movieId),
      ),
    );
  }

//STREAMING PLATFORMS BUTTON MECHANISM
  void _handleWhereToWatch(BuildContext context, int movieId) async {
    showDialog(
      context: context,
      builder: (context) => StreamingProvidersDialog(tmdbId: movieId),
    );
  }
}

//POSTER AND TITLE WIDGET
class PosterAndTitleWidget extends StatelessWidget {
  final dynamic movie;
  final Function(BuildContext, int, bool) onWatchlistToggle;
  final Function(BuildContext, int, bool) onCollectionToggle;
  final Function(BuildContext, int) onComment;
  final Function(BuildContext, int) onSave;
  final Function(BuildContext, int) onWhereToWatch;

  final bool isLoading;

  const PosterAndTitleWidget({
    super.key,
    required this.movie,
    required this.onWatchlistToggle,
    required this.onCollectionToggle,
    required this.onComment,
    required this.onSave,
    required this.onWhereToWatch,
    this.isLoading = false, //default to false
  });

  //isShimmer Method for poster and title shimmer.
  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade600,
            child: Container(
              width: 100,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade800,
                  highlightColor: Colors.grey.shade600,
                  child: Container(height: 20, width: 200, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade800,
                  highlightColor: Colors.grey.shade600,
                  child: Container(height: 16, width: 100, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: List.generate(4, (_) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade800,
                    highlightColor: Colors.grey.shade600,
                    child: Container(
                      width: 100,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildShimmer();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w500${movie['poster_path']}',
                      placeholder: (context, url) => const SizedBox(
                        height: 150,
                        width: 100,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                      width: 100,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TrailerButtonWidget(movieId: movie['id']), // ✅ Now aligned under poster
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie['title'] ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rating: ${movie['vote_average'] ?? 'N/A'} \u2B50',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      alignment: WrapAlignment.start,
                      children: [
                        AnimatedAddToWatchlistButton(
                          movieId: movie['id'],
                          onToggle: onWatchlistToggle,
                        ),
                        AnimatedSaveToCollectionButton(
                          movieId: movie['id'],
                          onToggle: onCollectionToggle,
                        ),
                        IconButton(
                          onPressed: () => onComment(context, movie['id']),
                          icon: const Icon(Icons.comment, color: Color(0xFF4C566A)),
                        ),
                        IconButton(
                          onPressed: () => onWhereToWatch(context, movie['id']),
                          icon: const Icon(Icons.tv, color: Color(0xFF4C566A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

//ANIMATED MECHANISM FOR WATCHLIST BUTTON START
class AnimatedAddToWatchlistButton extends StatefulWidget {
  final int movieId;
  final Function(BuildContext, int, bool) onToggle;

  const AnimatedAddToWatchlistButton({
    super.key,
    required this.movieId,
    required this.onToggle,
  });

  @override
  State<AnimatedAddToWatchlistButton> createState() =>
      _AnimatedAddToWatchlistButtonState();
}

class _AnimatedAddToWatchlistButtonState extends State<AnimatedAddToWatchlistButton> {
  bool _added = false;

  @override
  void initState() {
    super.initState();
    _loadWatchlistStatus();
  }

  Future<void> _loadWatchlistStatus() async {
    final inWatchlist = await _MovieDetailsScreenState().checkIfInWatchlist(widget.movieId);
    if (mounted) {
      setState(() {
        _added = inWatchlist;
      });
    }
  }

  void _toggle() {
    setState(() => _added = !_added);
    widget.onToggle(context, widget.movieId, _added);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
    child: _added
    ? ElevatedButton.icon(
    key: const ValueKey(true),
    onPressed: null, // still disabled
    icon: const Icon(Icons.check_circle, color: Colors.green),
    label: const Text('Added'),
    style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF007AFF),
    disabledBackgroundColor: const Color(0xFF007AFF), // ✅ override default
    disabledForegroundColor: Colors.white,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    )
        : ElevatedButton.icon(
    key: const ValueKey(false),
    onPressed: _toggle, // or any toggle logic
    icon: const Icon(Icons.playlist_add, color: Colors.white),
    label: const Text('Watchlist'),
    style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF007AFF),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    ),
      )
    );
  }
}
//ANIMATED MECHANISM FOR WATCHLIST BUTTON END
//ANIMATED MECHANISM FOR COLLECTION BUTTON START
class AnimatedSaveToCollectionButton extends StatefulWidget {
  final int movieId;
  final Function(BuildContext, int, bool) onToggle;

  const AnimatedSaveToCollectionButton({
    super.key,
    required this.movieId,
    required this.onToggle,
  });

  @override
  State<AnimatedSaveToCollectionButton> createState() =>
      _AnimatedSaveToCollectionButtonState();
}

class _AnimatedSaveToCollectionButtonState extends State<AnimatedSaveToCollectionButton> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSavedStatus();
  }

  Future<void> _loadSavedStatus() async {
    final inCollection = await _MovieDetailsScreenState().checkIfInCollection(widget.movieId);
    if (mounted) {
      setState(() {
        _saved = inCollection;
      });
    }
  }

  void _toggleSave() {
    setState(() => _saved = !_saved);
    widget.onToggle(context, widget.movieId, _saved);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleSave,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
    child: _saved
    ? ElevatedButton.icon(
    key: const ValueKey(true),
    onPressed: null, // Still disabled, but styled
    icon: const Icon(Icons.download_done, color: Colors.white),
    label: const Text('Saved'),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF2D9CDB),
      disabledBackgroundColor: const Color(0xFF2D9CDB),// ✅ Fix
    disabledForegroundColor: Colors.white,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    )
        : ElevatedButton.icon(
    key: const ValueKey(false),
    onPressed: _toggleSave, // Your toggle logic
    icon: const Icon(Icons.download_outlined),
    label: const Text('Collection'),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1DA1F2),// Light teal
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    ),
      )
    );
  }
}
//ANIMATED MECHANISM FOR SAVE TO COLLECTION END

//GENRES WIDGET
class GenresWidget extends StatelessWidget {
  final List<dynamic> genres;
  const GenresWidget({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Genres not available.', style: TextStyle(fontSize: 16)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Genres',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6.0,
            children: genres.map((genre) {
              return Chip(
                label: Text(genre['name']),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

//OVERVIEW WIDGET
class OverviewWidget extends StatelessWidget {
  final dynamic movie;
  const OverviewWidget({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            movie['overview'] ?? 'No description available.',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}



//RUNTIME AND RELEASE DATE WIDGET
class RuntimeReleaseWidget extends StatelessWidget {
  final int? runtime;
  final String? releaseDate;
  const RuntimeReleaseWidget({super.key, this.runtime, this.releaseDate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            runtime != null ? 'Runtime: $runtime mins' : 'Runtime: N/A',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            releaseDate != null ? 'Release Date: $releaseDate' : 'Release Date: N/A',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

//CAST SECTION WIDGET
class CastSectionWidget extends StatelessWidget {
  final int movieId;
  const CastSectionWidget({super.key, required this.movieId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: ApiService().fetchMovieCast(movieId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerCastList();
        } else if (snapshot.hasError) {
          return const Center(child: Text('Failed to load cast.'));
        } else {
          final cast = snapshot.data ?? [];
          return SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cast.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w200${cast[index]['profile_path']}',
                          placeholder: (context, url) => _shimmerBox(width: 80, height: 100),
                          errorWidget: (context, url, error) => const Icon(Icons.person),
                          width: 80,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          cast[index]['name'] ?? '',
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildShimmerCastList() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            children: [
              _shimmerBox(width: 80, height: 100),
              const SizedBox(height: 8),
              _shimmerBox(width: 80, height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerBox({required double width, required double height}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: Colors.grey.shade600,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}


 //TRAILER BUTTON WIDGET
class TrailerButtonWidget extends StatelessWidget {
  final int movieId;
  const TrailerButtonWidget({super.key, required this.movieId});

  Future<void> _launchYouTubeTrailer(String trailerKey, BuildContext context) async {
    final String webUrl = 'https://www.youtube.com/watch?v=$trailerKey';

    try {
      print('Attempting to open trailer URL: $webUrl');

      // Try opening with external app first
      bool launched = await launchUrlString(webUrl, mode: LaunchMode.externalApplication);

      if (!launched) {
        print('External app failed, falling back to in-app webview...');
        // Fallback to in-app webview
        launched = await launchUrlString(webUrl, mode: LaunchMode.inAppWebView);
      }

      if (!launched) {
        throw 'Could not launch YouTube trailer in any mode.';
      }
    } catch (e) {
      print('Error launching trailer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open trailer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: () async {
          try {
            final trailerKey = await ApiService().fetchTrailerUrl(movieId, type: '');
            if (trailerKey != null) {
              await _launchYouTubeTrailer(trailerKey, context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trailer not available.')),
              );
            }
          } catch (e) {
            print('Error fetching trailer key: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27AE60),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: const Text('Watch Trailer'),
      ),
    );
  }
}

class RelatedMoviesWidget extends StatelessWidget {
  final int movieId;
  const RelatedMoviesWidget({super.key, required this.movieId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: ApiService().fetchRelatedMovies(movieId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerRelatedList();
        } else if (snapshot.hasError) {
          return const Center(child: Text('Failed to load related movies.'));
        } else {
          final relatedMovies = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Related Movies',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: relatedMovies.length,
                    itemBuilder: (context, index) {
                      final movie = relatedMovies[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MovieDetailsScreen(
                                  movieId: movie['id'],
                                  movie: movie,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: CachedNetworkImage(
                                  imageUrl: 'https://image.tmdb.org/t/p/w200${movie['poster_path']}',
                                  placeholder: (context, url) =>
                                      _shimmerBox(width: 100, height: 150),
                                  errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                                  width: 100,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  movie['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildShimmerRelatedList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Related Movies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _shimmerBox(width: 100, height: 150),
                    const SizedBox(height: 8),
                    _shimmerBox(width: 100, height: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({required double width, required double height}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: Colors.grey.shade600,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}


// Trakt API Service
class TraktApiService {
  static final TraktAuth traktAuth = TraktAuth(); // Initialize TraktAuth

  // Like Movie
  static Future<void> likeMovie(int movieId) async {
    try {
      // Retrieve a valid access token
      final accessToken = await traktAuth.getValidAccessToken();
      if (accessToken == null) {
        throw Exception('User is not logged in or access token is missing.');
      }

      // Make the API call with the access token
      final response = await http.post(
        Uri.parse('https://api.trakt.tv/sync/likes'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'movies': [{'ids': {'trakt': movieId}}]}),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to like movie: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error liking movie: $e');
    }
  }

  // Save Movie
  static Future<void> saveMovie(int movieId) async {
    try {
      // Retrieve a valid access token
      final accessToken = await traktAuth.getValidAccessToken();
      if (accessToken == null) {
        throw Exception('User is not logged in or access token is missing.');
      }

      // Make the API call with the access token
      final response = await http.post(
        Uri.parse('https://api.trakt.tv/sync/collection'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'movies': [{'ids': {'trakt': movieId}}]}),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to save movie: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error saving movie: $e');
    }
  }
}

// JustWatch API Service
class JustWatchApiService {
  static Future<List<String>> getStreamingPlatforms(int movieId) async {
    final response = await http.get(
      Uri.parse('https://apis.justwatch.com/content/titles/movie/$movieId/locale/en_US'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final offers = data['offers'] as List<dynamic>;
      return offers.map((offer) => offer['provider_name'] as String).toList();
    } else {
      throw Exception('Failed to fetch streaming platforms');
    }
  }
}

// Local Storage Service
class LocalStorageService {
  static Future<void> saveLike(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final likedMovies = prefs.getStringList('liked_movies') ?? [];
    if (!likedMovies.contains(movieId.toString())) {
      likedMovies.add(movieId.toString());
      await prefs.setStringList('liked_movies', likedMovies);
    }
  }

  static Future<void> saveToCollection(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedMovies = prefs.getStringList('saved_movies') ?? [];
    if (!savedMovies.contains(movieId.toString())) {
      savedMovies.add(movieId.toString());
      await prefs.setStringList('saved_movies', savedMovies);
    }
  }
}

// Streaming Platforms Dialog
class StreamingPlatformsDialog extends StatelessWidget {
  final List<String> platforms;

  const StreamingPlatformsDialog({super.key, required this.platforms});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Where to Watch'),
      content: platforms.isEmpty
          ? const Text('No streaming platforms available.')
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: platforms.map((platform) => Text(platform)).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
