import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'trakt_auth.dart';
import 'package:intl/intl.dart' as intl;
import 'package:timeago/timeago.dart' as timeago;

class CommentsScreen extends StatefulWidget {
  final int movieId;
  const CommentsScreen({super.key, required this.movieId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TraktAuth traktAuth = TraktAuth();
  late Future<List<Map<String, dynamic>>> comments;
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  bool _spoiler = false;

  @override
  void initState() {
    super.initState();
    comments = fetchComments(widget.movieId);
  }

  Future<List<Map<String, dynamic>>> fetchComments(int tmdbId) async {
    final traktId = await getTraktIdFromTmdb(tmdbId);
    final response = await http.get(
      Uri.parse('https://api.trakt.tv/movies/$traktId/comments'),
      headers: {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch comments: ${response.statusCode}');
    }
  }

  Future<int?> getTraktIdFromTmdb(int tmdbId) async {
    final accessToken = await traktAuth.getAccessToken();
    final response = await http.get(
      Uri.parse('https://api.trakt.tv/search/tmdb/$tmdbId?type=movie'),
      headers: {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        return data[0]['movie']['ids']['trakt'];
      }
    }
    return null;
  }

  Future<void> submitComment(String commentText) async {
    if (commentText.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    final traktId = await getTraktIdFromTmdb(widget.movieId);
    final accessToken = await traktAuth.getAccessToken();

    final response = await http.post(
      Uri.parse('https://api.trakt.tv/comments'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': 'a64b0dd1cbe45040d76ffd4d457c90e96aebb9d86f49202823568aadf3df299d',
      },
      body: jsonEncode({
        "movie": {
          "ids": {"trakt": traktId}
        },
        "comment": commentText,
        "spoiler": _spoiler
      }),
    );

    if (response.statusCode == 201) {
      _controller.clear();
      setState(() {
        _spoiler = false;
        comments = fetchComments(widget.movieId);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit comment: ${response.body}')),
      );
    }

    setState(() => _isSubmitting = false);
  }

  Widget buildCommentTile(Map<String, dynamic> comment) {
    final user = comment['user'] ?? {};
    final username = user['username']?.toString().trim().isNotEmpty == true
        ? user['username']
        : 'Anonymous';
    final avatarUrl = user['images']?['avatar']?['full'];
    final isSpoiler = comment['spoiler'] ?? false;
    final createdAt = DateTime.tryParse(comment['created_at'] ?? '');
    final timestamp = createdAt != null ? timeago.format(createdAt) : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.purple.shade200,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null
                ? Text(
              username.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timestamp,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isSpoiler ? 'Spoiler alert!' : comment['comment'] ?? '',
                  style: TextStyle(
                    color: isSpoiler ? Colors.red : Colors.white,
                    fontStyle:
                    isSpoiler ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: comments,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error loading comments: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No comments yet.'));
                } else {
                  final commentsList = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    itemCount: commentsList.length,
                    itemBuilder: (context, index) => buildCommentTile(commentsList[index]),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Type a comment (English, 5+ words)'),
                  ),
                ),
                IconButton(
                  icon: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send),
                  onPressed: _isSubmitting
                      ? null
                      : () => submitComment(_controller.text),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12.0, bottom: 12.0),
            child: Row(
              children: [
                Checkbox(
                  value: _spoiler,
                  onChanged: (value) {
                    setState(() => _spoiler = value ?? false);
                  },
                ),
                const Text('Spoiler alert!'),
              ],
            ),
          )
        ],
      ),
    );
  }
}
