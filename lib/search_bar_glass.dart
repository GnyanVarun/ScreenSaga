import 'dart:ui';
import 'package:flutter/material.dart';

class SearchBarGlass extends StatelessWidget {
  const SearchBarGlass({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to search screen
        Navigator.pushNamed(context, '/search');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search, color: Colors.white70),
                  SizedBox(width: 10),
                  Text("Search movies, series...", style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
