import 'dart:async';
import 'package:flutter/material.dart';
import 'movie_service.dart';
import 'series_details.dart';

class SeriesListScreen extends StatefulWidget {
  final List<dynamic> initialSeries;

  const SeriesListScreen({super.key, required this.initialSeries});

  @override
  _SeriesListScreenState createState() => _SeriesListScreenState();
}

class _SeriesListScreenState extends State<SeriesListScreen> {
  final ApiService _apiService = ApiService();
  late List<dynamic> _tvSeries;
  int _currentPage = 1;
  bool _isLoading = false;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tvSeries = List.from(widget.initialSeries);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent && !_isLoading) {
      _fetchTVSeries();
    }
  }

  Future<void> _fetchTVSeries() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final series = await _apiService.fetchTVSeries(page: _currentPage + 1);
      setState(() {
        _currentPage++;
        _tvSeries.addAll(series);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching TV series: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _searchSeries(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _tvSeries = List.from(widget.initialSeries);
          _currentPage = 1;
        });
        return;
      }

      setState(() => _isLoading = true);

      try {
        final results = await _apiService.searchTVSeries(query: query);
        setState(() {
          _tvSeries = results;
          _currentPage = 1;
        });
      } catch (e) {
        print('Error searching series: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Popular TV Series'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: _searchSeries,
              decoration: InputDecoration(
                hintText: 'Search series...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
      body: NotificationListener<ScrollEndNotification>(
        onNotification: (scrollEnd) {
          if (scrollEnd.metrics.pixels == scrollEnd.metrics.maxScrollExtent) {
            _fetchTVSeries();
          }
          return true;
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _tvSeries.length + 1,
          itemBuilder: (context, index) {
            if (index == _tvSeries.length) {
              return _isLoading ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
            }

            final series = _tvSeries[index];
            return ListTile(
              leading: series['poster_path'] != null
                  ? Image.network(
                'https://image.tmdb.org/t/p/w92${series['poster_path']}',
                width: 50,
                height: 75,
                fit: BoxFit.cover,
              )
                  : const Icon(Icons.tv, size: 50),
              title: Text(series['name']),
              subtitle: Text('Rating: ${series['vote_average']}'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeriesDetailsScreen(seriesId: series['id'],series: null,),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}