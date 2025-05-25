import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'movie_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'trakt_auth.dart';
import'series_comments_screen.dart';
import'series_streaming_dialog.dart';
import 'dart:convert';

class SeriesDetailsScreen extends StatefulWidget {
  final int seriesId;

  const SeriesDetailsScreen({super.key, required this.seriesId, required series});

  @override
  _SeriesDetailsScreenState createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _seriesDetails;
  List<dynamic>? _cast;
  List<dynamic>? _relatedSeries;
  bool _isLoading = true;
  bool isInWatchlist = false;
  bool isInCollection = false;

  @override
  void initState() {
    super.initState();
    _fetchSeriesDetails();
    _loadSeriesState(); // Load saved watchlist/collection status
    _fetchWatchlistAndCollectionStatus();

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      _loadSeriesState(); // refresh when coming back to this screen
    }

  }

  Future<void> _fetchWatchlistAndCollectionStatus() async {
    final watchlist = await TraktAuth().isSeriesInWatchlist(widget.seriesId);
    final collection = await TraktAuth().isSeriesInCollection(widget.seriesId);

    setState(() {
      isInWatchlist = watchlist;
      isInCollection = collection;
    });
  }

  Future<void> _loadSeriesState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isInWatchlist = prefs.getBool('series_watchlist_${widget.seriesId}') ?? false;
      isInCollection = prefs.getBool('series_collection_${widget.seriesId}') ?? false;
    });
  }

  Future<void> _fetchSeriesDetails() async {
    try {
      final details = await _apiService.fetchTVDetails(widget.seriesId);
      final cast = await _apiService.fetchTVCast(widget.seriesId);
      final related = await _apiService.fetchRelatedTVSeries(widget.seriesId);

      setState(() {
        _seriesDetails = details;
        _cast = cast;
        _relatedSeries = related;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching series details: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isInWatchlist = !isInWatchlist;
    });
    prefs.setBool('series_watchlist_${widget.seriesId}', isInWatchlist);

    if (isInWatchlist) {
      await TraktAuth().addShowToWatchlist(widget.seriesId);

      // 🆕 Also add to local SharedPreferences watchlist
      List<String> savedWatchlist = prefs.getStringList('watchlist') ?? [];

      Map<String, dynamic> seriesData = {
        'id': widget.seriesId,
        'title': _seriesDetails?['name'] ?? '',
        'posterPath': _seriesDetails?['poster_path'] ?? '',
        'type': 'show',
      };

      bool alreadyExists = savedWatchlist.any((item) {
        final decoded = jsonDecode(item);
        return decoded['id'] == widget.seriesId && decoded['type'] == 'show';
      });

      if (!alreadyExists) {
        savedWatchlist.add(jsonEncode(seriesData));
        await prefs.setStringList('watchlist', savedWatchlist);
      }

    } else {
      await TraktAuth().removeShowFromWatchlist(widget.seriesId);

      // 🆕 Remove from local SharedPreferences watchlist
      List<String> savedWatchlist = prefs.getStringList('watchlist') ?? [];

      savedWatchlist.removeWhere((item) {
        final decoded = jsonDecode(item);
        return decoded['id'] == widget.seriesId && decoded['type'] == 'show';
      });

      await prefs.setStringList('watchlist', savedWatchlist);
    }
  }

  Future<void> _toggleCollection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isInCollection = !isInCollection;
    });
    prefs.setBool('series_collection_${widget.seriesId}', isInCollection);

    if (isInCollection) {
      await TraktAuth().addShowToCollection(widget.seriesId);
    } else {
      await TraktAuth().removeShowFromCollection(widget.seriesId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Series Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _seriesDetails == null
          ? const Center(child: Text('No details available'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster + Trailer
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        'https://image.tmdb.org/t/p/w200${_seriesDetails!['poster_path']}',
                        width: 100,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SeriesTrailerButtonWidget(seriesId: widget.seriesId),
                  ],
                ),
                const SizedBox(width: 16),
                // Title + Info + Buttons
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _seriesDetails!['name'] ?? '',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // First Air Date
                      Text(
                        'First Air Date: ${_seriesDetails!['first_air_date'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      // Runtime
                      Text(
                        'Episode Runtime: ${_seriesDetails!['episode_run_time']?.join(', ') ?? 'N/A'} min',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      // Rating
                      Row(
                        children: [
                          Text(
                            'Rating: ${_seriesDetails!['vote_average']}',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action Buttons
                      Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                        children: [
                        // Watchlist Button with Scale Animation
                          // Watchlist Button with Animation
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: isInWatchlist
                                ? ElevatedButton.icon(
                              key: const ValueKey(true),
                              onPressed: _toggleWatchlist,
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              label: const Text('In Watchlist'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF), // Bright blue
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                            )
                                : ElevatedButton.icon(
                              key: const ValueKey(false),
                              onPressed: _toggleWatchlist,
                              icon: const Icon(Icons.playlist_add, color: Colors.white),
                              label: const Text('Add Watchlist'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF), // Bright blue
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                            ),
                          ),

// Collection Button with Animation
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: isInCollection
                                ? ElevatedButton.icon(
                              key: const ValueKey(true),
                              onPressed: _toggleCollection,
                              icon: const Icon(Icons.check_circle, color: Colors.white),
                              label: const Text('In Collection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2D9CDB), // Sky blue for saved
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                            )
                                : ElevatedButton.icon(
                              key: const ValueKey(false),
                              onPressed: _toggleCollection,
                              icon: const Icon(Icons.download_outlined, color: Colors.white),
                              label: const Text('Add Collection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DA1F2), // Bright teal-blue
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed: _openComments,
                            icon: const Icon(Icons.comment),
                          ),
                          IconButton(
                            onPressed: _openStreamingPlatforms,
                            icon: const Icon(Icons.tv),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 19.0),
            const Text('Overview:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 9),
            Text(_seriesDetails!['overview'] ?? 'No description available'),
            const SizedBox(height: 19.0),

            const Text('Genres:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 9.0,
              children: _seriesDetails!['genres']
                  .map<Widget>((genre) => Chip(label: Text(genre['name'])))
                  .toList(),
            ),
            const SizedBox(height: 16.0),

            _buildCastSection(),
            _buildRelatedSeriesSection(),
          ],
        ),
      ),
    );
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeriesCommentsScreen(seriesId: widget.seriesId),
      ),
    );
  }

  void _openStreamingPlatforms() {
    showDialog(
      context: context,
      builder: (context) => SeriesStreamingProvidersDialog(tmdbId: widget.seriesId),
    );
  }


  Widget _buildTrailerButton() {
    return SeriesTrailerButtonWidget(seriesId: widget.seriesId);
  }

  Widget _buildCastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cast:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _cast == null || _cast!.isEmpty
            ? const Text('No cast information available')
            : SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _cast!.length,
            itemBuilder: (context, index) {
              final actor = _cast![index];
              return Container(
                width: 100,
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: actor['profile_path'] != null
                          ? NetworkImage('https://image.tmdb.org/t/p/w200${actor['profile_path']}')
                          : null,
                      child: actor['profile_path'] == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 40,
                      child: Text(
                        actor['name'] ?? 'Unknown',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRelatedSeriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Related Series:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _relatedSeries == null || _relatedSeries!.isEmpty
            ? const Text('No Related Series Found')
            : SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedSeries!.length,
            itemBuilder: (context, index) {
              final series = _relatedSeries![index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeriesDetailsScreen(seriesId: series['id'], series: null),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://image.tmdb.org/t/p/w200${series['poster_path']}',
                          width: 100,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 100,
                        child: Text(
                          series['name'] ?? 'Unknown',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
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
    );
  }
}

// Trailer Button Widget
class SeriesTrailerButtonWidget extends StatelessWidget {
  final int seriesId;

  const SeriesTrailerButtonWidget({super.key, required this.seriesId});

  Future<void> _launchYouTubeTrailer(String trailerKey, BuildContext context) async {
    final String trailerUrl = 'https://www.youtube.com/watch?v=$trailerKey';

    try {
      debugPrint('Attempting to open trailer URL: $trailerUrl');

      // Try launching via external app first
      bool launched = await launchUrlString(trailerUrl, mode: LaunchMode.externalApplication);

      if (!launched) {
        debugPrint('External launch failed. Falling back to in-app webview...');
        // Fallback to in-app webview
        launched = await launchUrlString(trailerUrl, mode: LaunchMode.inAppWebView);
      }

      if (!launched) {
        throw 'Could not launch YouTube trailer via app or browser.';
      }
    } catch (e) {
      debugPrint('Error launching trailer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open trailer: $e')),
      );
    }
  }

  Future<void> _playTrailer(BuildContext context) async {
    try {
      final trailerKey = await ApiService().fetchTVTrailerUrl(seriesId);
      if (trailerKey != null) {
        await _launchYouTubeTrailer(trailerKey, context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trailer not available.')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching trailer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch trailer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: () => _playTrailer(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27AE60), // ✅ Emerald Green
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text(
          'Watch Trailer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}