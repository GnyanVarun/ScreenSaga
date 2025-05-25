import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

class BannerCarousel extends StatelessWidget {

  final List<dynamic> items;
  const BannerCarousel({super.key, required this.items,});

  @override
  Widget build(BuildContext context) {
    return CarouselSlider.builder(
      itemCount: items.length,
      itemBuilder: (context, index, _) {
        final banner = items[index];
        return Stack(
          children: [
            Image.network(
              banner['imageUrl'],
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(banner['title'], style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {}, // Navigate to detail
                    child: Text("Watch Now"),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      options: CarouselOptions(
        height: 250,
        autoPlay: true,
        viewportFraction: 1.0,
        enlargeCenterPage: false,
      ),
    );
  }
}
