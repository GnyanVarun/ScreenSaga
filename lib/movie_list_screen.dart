import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'movie_service.dart';
import 'movie_details.dart';

class MovieListScreen extends StatefulWidget {
  final List<dynamic> initialMovies;

  const MovieListScreen({super.key, required this.initialMovies});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late List<dynamic> movies;
  late ScrollController _scrollController;
  Timer? _debounce;
  bool isLoading = false;
  int currentPage = 1;

  @override
  void initState() {
    super.initState();
    movies = widget.initialMovies;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent &&
        !isLoading) {
      fetchNextPage();
    }
  }

  Future<void> fetchNextPage() async {
    setState(() {
      isLoading = true;
    });

    try {
      final newMovies = await ApiService().fetchMovies(page: currentPage + 1);
      setState(() {
        currentPage++;
        movies.addAll(newMovies);
      });
    } catch (e) {
      print('Error loading next page: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> searchMovies(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          movies = widget.initialMovies;
          currentPage = 1;
        });
        return;
      }

      setState(() {
        isLoading = true;
      });

      try {
        final results = await ApiService().searchMovies(query: query);
        setState(() {
          movies = results;
          currentPage = 1;
        });
      } catch (e) {
        print('Error searching movies: $e');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // backgroundColor: Colors.indigo,
        title: const Text('Movies'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: searchMovies,
              decoration: InputDecoration(
                hintText: 'Search movies...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: movies.length + 1,
        itemBuilder: (context, index) {
          if (index == movies.length) {
            return isLoading
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox.shrink();
          }

          final movie = movies[index];
          return ListTile(
            leading: CachedNetworkImage(
              imageUrl:
              'https://image.tmdb.org/t/p/w200${movie['poster_path']}',
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
            title: Text(
              movie['title'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Rating: ${movie['vote_average']}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MovieDetailsScreen(movieId: movie['id'], movie: movie),
                ),
              );
            },
          );
        },
      ),
    );
  }
}