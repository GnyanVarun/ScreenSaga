import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For encoding/decoding data

class LocalStorageHelper {
  // Key for storing the watchlist in SharedPreferences
  static const String _watchlistKey = 'watchlist_items';

  // Save the watchlist items to local storage
  static Future<void> saveWatchlistItems(List<Map<String, dynamic>> items) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String encodedItems = jsonEncode(items);  // Convert list to JSON string
    await prefs.setString(_watchlistKey, encodedItems);  // Save JSON string in SharedPreferences
  }

  // Retrieve the watchlist items from local storage
  static Future<List<Map<String, dynamic>>> getWatchlistItems() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWatchlist = prefs.getStringList('watchlist') ?? [];

    return savedWatchlist
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();
  }

  // Remove a specific item from the watchlist
  static Future<void> removeFromWatchlist(Map<String, dynamic> item) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> items = await getWatchlistItems();  // Get current watchlist items

    // Remove the item if it exists in the list
    items.removeWhere((watchlistItem) => watchlistItem['id'] == item['id']);

    // Save the updated list back to local storage
    await saveWatchlistItems(items);
  }

  // Clear all watchlist items
  static Future<void> clearWatchlist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_watchlistKey);  // Remove the watchlist key from SharedPreferences
  }
}
