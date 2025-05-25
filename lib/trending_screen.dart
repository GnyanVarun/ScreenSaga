import 'package:flutter/material.dart';
import 'movie_service.dart';
import 'movie_details.dart';
import 'series_details.dart';
import 'package:shimmer/shimmer.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({Key? key}) : super(key: key);

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> trendingItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrending();
  }

  Future<void> _fetchTrending() async {
    try {
      final items = await _apiService.fetchTrendingMoviesAndSeries();
      setState(() {
        trendingItems = items;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching trending content: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Trending Now"),
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.background,
        foregroundColor: theme.appBarTheme.foregroundColor ?? colorScheme.onBackground,
        elevation: 1,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: isLoading
            ? _buildShimmerGrid()
            : GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.55,
            crossAxisSpacing: 1,
            mainAxisSpacing: 0,
          ),
          itemCount: trendingItems.length,
          itemBuilder: (context, index) {
            final item = trendingItems[index];
            final isMovie = item['media_type'] == 'movie';

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isMovie
                        ? MovieDetailsScreen(movie: item, movieId: item['id'])
                        : SeriesDetailsScreen(series: item, seriesId: item['id']),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://image.tmdb.org/t/p/w500${item['poster_path']}',
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.error, color: colorScheme.error),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['title'] ?? item['name'] ?? 'No Title',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onBackground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,       // lighter base color
      highlightColor: Colors.grey.shade100,  // lighter highlight color
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 1,
          mainAxisSpacing: 0,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,   // lighter shimmer box
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 70,
                height: 15,
                color: Colors.grey.shade300,   // lighter shimmer box
              ),
              const SizedBox(height: 6),
              Container(
                width: 50,
                height: 15,
                color: Colors.grey.shade300,   // lighter shimmer box
              ),
            ],
          );
        },
      ),
    );
  }
}
