import 'package:flutter/material.dart';
import 'movie_list_screen.dart';
import 'series_list_screen.dart';
import 'movie_service.dart';
import 'profile_screen.dart'; // Import Profile screen

class TabNavigation extends StatefulWidget {
  const TabNavigation({super.key});

  @override
  State<TabNavigation> createState() => _TabNavigationState();
}

class _TabNavigationState extends State<TabNavigation> {
  int _selectedIndex = 0;

  Future<List<dynamic>>? futureMovies;
  Future<List<dynamic>>? futureTVSeries;

  @override
  void initState() {
    super.initState();
    ApiService apiService = ApiService();
    futureMovies = apiService.fetchMovies();
    futureTVSeries = apiService.fetchTVSeries(page: 1);
  }

  List<Widget> _widgetOptions() {
    return [
      FutureBuilder<List<dynamic>>(
        future: futureMovies,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return MovieListScreen(initialMovies: snapshot.data!);
          } else {
            return const Center(child: Text('No movies found.'));
          }
        },
      ),
      FutureBuilder<List<dynamic>>(
        future: futureTVSeries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData && snapshot.data != null) {
            return SeriesListScreen(initialSeries: snapshot.data!);
          } else {
            return const Center(child: Text('No series found.'));
          }
        },
      ),
      ProfileScreen(), // Add Profile screen
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ScreenSaga',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _widgetOptions()[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.movie),
            label: 'Movies',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tv),
            label: 'Series',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), // Profile icon
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        backgroundColor: Colors.indigo,
        onTap: _onItemTapped,
        showUnselectedLabels: true,
        selectedFontSize: 14,
        unselectedFontSize: 12,
      ),
    );
  }
}
