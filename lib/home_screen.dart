import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:screensaga/settings_screen.dart';
import 'package:screensaga/watched_screen.dart';
import 'movie_service.dart';
import 'side_menu.dart';
import 'movie_details.dart';
import 'series_details.dart';
import 'content_search_delegate.dart';
import 'trending_screen.dart';
import 'watchlist_screen.dart';
import 'collection_screen.dart';
import 'dart:io' show Platform;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _tmdbService = ApiService();
  List<dynamic> upcomingContent = [];
  List<dynamic> newReleases = [];
  List<dynamic> popularSeries = [];

  late PageController _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
    _fetchData();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients && upcomingContent.isNotEmpty) {
        _currentPage = (_currentPage + 1) % upcomingContent.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchData() async {
    try {
      final upcomingMovies = await _tmdbService.fetchUpcomingMovies();
      final upcomingSeries = await _tmdbService.fetchUpcomingSeries();
      final releases = await _tmdbService.fetchNewReleases();
      final series = await _tmdbService.fetchPopularSeries();

      setState(() {
        upcomingContent = [...upcomingMovies, ...upcomingSeries];
        newReleases = releases;
        popularSeries = series;
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: SideMenu(onItemSelected: _onDrawerItemSelected),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 2,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
        title: Text(
          "ScreenSaga",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                delegate: _SearchBarDelegate(_buildSearchBar(context)),
                pinned: true,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildUpcomingCarousel()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverToBoxAdapter(child: _buildSection("New Releases", newReleases, true)),
              const SliverToBoxAdapter(child: SizedBox(height: 2)),
              SliverToBoxAdapter(child: _buildSection("Popular Series", popularSeries, false)),
            ],
          ),
        ),
      ),
    );
  }

  void _onDrawerItemSelected(String selected) {
    final navMap = {
      "Trending": () => const TrendingScreen(),
      "Watchlist": () => const WatchlistScreen(),
      "Collection": () => const CollectionScreen(),
      "Watched": () => const WatchedScreen(),
      "Settings": () => SettingsScreen(),
    };

    if (navMap.containsKey(selected)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => navMap[selected]!()),
      );
    }
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () async {
        final result = await showSearch(
          context: context,
          delegate: ContentSearchDelegate(apiService: _tmdbService),
        );
        if (result != null) {
          if (result['media_type'] == 'movie') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailsScreen(
                  movie: result,
                  movieId: result['id'],
                ),
              ),
            );
          } else if (result['media_type'] == 'tv') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeriesDetailsScreen(
                  series: result,
                  seriesId: result['id'],
                ),
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.hintColor),
              const SizedBox(width: 10),
              Text(
                "Search movies or series...",
                style: TextStyle(color: theme.hintColor, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingCarousel() {
    final theme = Theme.of(context);
    final isLoading = upcomingContent.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            "Upcoming Releases",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
        ),
        SizedBox(
          height: Platform.isWindows ? 360 : 300,
          child: isLoading
              ? ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (_, __) => _buildShimmerCard(),
          )
              : PageView.builder(
            controller: _pageController,
            itemCount: upcomingContent.length,
            itemBuilder: (context, index) {
              final item = upcomingContent[index];
              final isMovie = item['media_type'] == 'movie' || item['title'] != null;
              return _buildCarouselCard(item, isMovie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(dynamic item, bool isMovie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => isMovie
                ? MovieDetailsScreen(movie: item, movieId: item['id'])
                : SeriesDetailsScreen(series: item, seriesId: item['id']),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                'https://image.tmdb.org/t/p/w500${item['poster_path']}',
                fit: BoxFit.cover,
                width: double.infinity,
                height: Platform.isWindows ? 360 : 300,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  color: Colors.black.withOpacity(0.5),
                  child: Text(
                    item['title'] ?? item['name'] ?? 'No Title',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items, bool isMovie) {
    final theme = Theme.of(context);
    final isLoading = items.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
        ),
        SizedBox(
          height: 230,
          child: isLoading
              ? ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            itemBuilder: (_, __) => _buildShimmerCard(),
          )
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildMovieCard(items[index], isMovie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(dynamic item, bool isMovie) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => isMovie
                ? MovieDetailsScreen(movie: item, movieId: item['id'])
                : SeriesDetailsScreen(series: item, seriesId: item['id']),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 140,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  'https://image.tmdb.org/t/p/w500${item['poster_path']}',
                  fit: BoxFit.cover,
                  width: 130,
                  height: 180,
                ),
              ),
              const SizedBox(height: 5),
              Flexible(
                child: Text(
                  item['title'] ?? item['name'] ?? 'No Title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            Container(
              width: 130,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 100,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget searchBar;

  _SearchBarDelegate(this.searchBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Colors.transparent,
      child: searchBar,
    );
  }

  @override
  double get maxExtent => 70;

  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
