import 'dart:io';

import 'package:xml/xml.dart';

/// Service to parse OPML files.
class OpmlService {
  /// Parses an OPML file and returns a list of RSS feed URLs.
  Future<List<String>> parseOpml(File file) async {
    final content = await file.readAsString();
    final document = XmlDocument.parse(content);

    final urls = <String>[];
    final outlines = document.findAllElements('outline');

    for (var outline in outlines) {
      final xmlUrl = outline.getAttribute('xmlUrl');
      if (xmlUrl != null && xmlUrl.isNotEmpty) {
        urls.add(xmlUrl);
      }
    }

    return urls;
  }
}
