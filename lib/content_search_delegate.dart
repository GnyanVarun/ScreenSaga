import 'package:flutter/material.dart';
import 'movie_details.dart';
import 'series_details.dart';
import 'movie_service.dart';

class ContentSearchDelegate extends SearchDelegate {
  final ApiService apiService;
  String _selectedFilter = 'all'; // 'all', 'movie', or 'series'

  ContentSearchDelegate({required this.apiService});

  @override
  String? get searchFieldLabel => 'Search movies or series';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(fontSize: 16, color: Colors.white);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchSuggestions(context);
  }

  Widget _buildSearchSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Start typing to search..."),
      );
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              child: Wrap(
                spacing: 12.0,
                children: [
                  _buildChoiceChip(
                    context: context,
                    label: "All",
                    value: 'all',
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  _buildChoiceChip(
                    context: context,
                    label: "Movies",
                    value: 'movie',
                    selected: _selectedFilter == 'movie',
                    onTap: () => setState(() => _selectedFilter = 'movie'),
                  ),
                  _buildChoiceChip(
                    context: context,
                    label: "Series",
                    value: 'series',
                    selected: _selectedFilter == 'series',
                    onTap: () => setState(() => _selectedFilter = 'series'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: apiService.searchAllContent(query: query),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No results found."));
                  }

                  final filteredResults = snapshot.data!.where((item) {
                    if (_selectedFilter == 'all') return true;
                    return (_selectedFilter == 'movie' && item['type'] == 'movie') ||
                        (_selectedFilter == 'series' && (item['type'] == 'tv' || item['type'] == 'series'));
                  }).toList();

                  return ListView.builder(
                    itemCount: filteredResults.length,
                    itemBuilder: (context, index) {
                      final item = filteredResults[index];
                      final isMovie = item['type'] == 'movie';

                      return ListTile(
                        leading: item['poster_path'] != null
                            ? Image.network(
                          'https://image.tmdb.org/t/p/w200${item['poster_path']}',
                          width: 50,
                          fit: BoxFit.cover,
                        )
                            : const Icon(Icons.movie),
                        title: Text(item['title']),
                        subtitle: Text(isMovie ? "Movie" : "Series"),
                        onTap: () {
                          close(context, null);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isMovie
                                  ? MovieDetailsScreen(movie: item, movieId: item['id'])
                                  : SeriesDetailsScreen(series: item, seriesId: item['id']),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChoiceChip({
    required BuildContext context,
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color selectedColor = isDark ? Colors.tealAccent.shade400 : Colors.deepPurple;
    final Color backgroundColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final Color textColor = selected
        ? Colors.white
        : isDark ? Colors.white70 : Colors.black;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (_) => onTap(),
    );
  }
}
