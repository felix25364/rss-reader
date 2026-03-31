import 'package:dart_rss/dart_rss.dart';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Represents a parsed RSS item mapped to our domain.
class ParsedArticle {
  final String title;
  final String link;
  final String content;
  final DateTime pubDate;

  ParsedArticle({
    required this.title,
    required this.link,
    required this.content,
    required this.pubDate,
  });
}

/// Service to fetch and parse RSS feeds.
class RssService {
  /// Fetches an RSS feed from [url] and parses it into [ParsedArticle]s.
  Future<List<ParsedArticle>> fetchFeed(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final feed = RssFeed.parse(response.body);

        return feed.items.map((item) {
          final pubDateStr = item.pubDate ?? '';
          DateTime pubDate;
          try {
            pubDate = parseDateTime(pubDateStr);
          } catch (_) {
            pubDate = DateTime.now(); // Fallback if parsing fails
          }

          return ParsedArticle(
            title: item.title ?? 'No title',
            link: item.link ?? '',
            content: item.description ?? '', // Using description as content
            pubDate: pubDate,
          );
        }).toList();
      } else {
        throw Exception('Failed to load feed, status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching feed $url: $e');
      return [];
    }
  }

  /// Helper to parse standard RSS date strings (RFC 822) into DateTime.
  /// Note: A robust implementation might use the intl package for complex date parsing.
  DateTime parseDateTime(String dateString) {
    if (dateString.isEmpty) return DateTime.now();
    // Simplified parsing, assuming mostly standard formats or ISO8601
    // dart_rss already does some parsing, but pubDate is a String.
    try {
       // Attempt to parse standard RFC 822 date usually returned by RSS
       // Example: "Wed, 02 Oct 2002 13:00:00 GMT"
       // Dart's DateTime.parse supports ISO-8601, not RFC-822 natively perfectly.
       // However, HttpDate.parse handles RFC 1123/822.
       return HttpDate.parse(dateString);
    } catch (e) {
       // Fallback
       try {
         return DateTime.parse(dateString);
       } catch (e2) {
         return DateTime.now();
       }
    }
  }
}
