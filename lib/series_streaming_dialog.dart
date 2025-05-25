import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'justwatch_service.dart';
//import 'package:url_launcher/url_launcher.dart';

class SeriesStreamingProvidersDialog extends StatefulWidget {
  final int tmdbId;
  const SeriesStreamingProvidersDialog({super.key, required this.tmdbId});

  @override
  State<SeriesStreamingProvidersDialog> createState() => _SeriesStreamingProvidersDialogState();
}

class _SeriesStreamingProvidersDialogState extends State<SeriesStreamingProvidersDialog> {
  List<Map<String, dynamic>> platforms = [];
  bool loading = true;
  String selectedRegion = 'IN';

  final List<String> regions = ['IN', 'US', 'GB', 'CA', 'DE'];

  @override
  void initState() {
    super.initState();
    fetchPlatforms();
  }

  Future<void> fetchPlatforms() async {
    print('🔍 TMDB Series ID: ${widget.tmdbId}');
    print('🌍 Region: $selectedRegion');

    try {
      final providers = await JustWatchService.getWatchProvidersForSeries(
        tmdbId: widget.tmdbId,
        region: selectedRegion,
      );
      print('✅ Series Providers: $providers');

      setState(() {
        platforms = providers;
        loading = false;
      });
    } catch (e) {
      print('❌ Error fetching series platforms: $e');
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.black.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Streaming Platforms', style: TextStyle(color: Colors.white, fontSize: 18)),
                DropdownButton<String>(
                  dropdownColor: Colors.grey[850],
                  value: selectedRegion,
                  icon: const Icon(Icons.language, color: Colors.white),
                  underline: Container(),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedRegion = value;
                        loading = true;
                      });
                      fetchPlatforms();
                    }
                  },
                  items: regions
                      .map((region) => DropdownMenuItem(
                    value: region,
                    child: Text(region),
                  ))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : platforms.isEmpty
                  ? const Center(
                child: Text(
                  'No platforms found. Try changing the region.',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: platforms.length,
                itemBuilder: (context, index) {
                  final provider = platforms[index];
                  final providerName = provider['provider_name'] ?? 'Unknown';
                  final logoPath = provider['logo_path'];
                  final logoUrl = logoPath != null
                      ? 'https://image.tmdb.org/t/p/w45$logoPath'
                      : null;

                  return Card(
                    color: Colors.grey[900],
                    child: ListTile(
                      leading: logoUrl != null
                          ? Image.network(logoUrl, width: 32, height: 32)
                          : const Icon(Icons.tv, color: Colors.white),
                      title: Text(providerName, style: const TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
