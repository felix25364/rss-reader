import 'package:dart_rss/dart_rss.dart';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Represents a parsed RSS item mapped to our domain.
class ParsedArticle {
  final String title;
  final String link;
  final String content;
  final String? imageUrl;
  final DateTime pubDate;

  ParsedArticle({
    required this.title,
    required this.link,
    required this.content,
    this.imageUrl,
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

          // Try to extract an image from enclosure or media tags
          String? imageUrl;
          if (item.enclosure?.url != null && (item.enclosure?.type?.startsWith('image/') ?? false)) {
            imageUrl = item.enclosure!.url;
          } else if (item.media?.contents.isNotEmpty ?? false) {
            final mediaContent = item.media!.contents.firstWhere(
                (m) => m.type?.startsWith('image/') ?? false,
                orElse: () => item.media!.contents.first);
            if (mediaContent.url != null) {
              imageUrl = mediaContent.url;
            }
          } else if (item.content?.images.isNotEmpty ?? false) {
            imageUrl = item.content!.images.first;
          }

          // Fallback to searching the HTML description for an img tag
          if (imageUrl == null && item.description != null) {
            final RegExp imgRegex = RegExp(r'<img[^>]+src="([^">]+)"');
            final match = imgRegex.firstMatch(item.description!);
            if (match != null && match.groupCount >= 1) {
              imageUrl = match.group(1);
            }
          }

          // In standard RSS sometimes description is content, sometimes it's split.
          final contentStr = (item.content?.value != null && item.content!.value!.isNotEmpty)
              ? item.content!.value!
              : item.description ?? '';

          return ParsedArticle(
            title: item.title ?? 'No title',
            link: item.link ?? '',
            content: contentStr,
            imageUrl: imageUrl,
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
