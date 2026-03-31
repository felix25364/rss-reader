import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../database/connection.dart';
import '../models/database.dart';
import '../services/classifier_service.dart';
import '../services/opml_service.dart';
import '../services/rss_service.dart';

/// Database provider.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(db.close);
  return db;
});

/// Services providers.
final rssServiceProvider = Provider((ref) => RssService());
final opmlServiceProvider = Provider((ref) => OpmlService());
final classifierServiceProvider = Provider((ref) => ClassifierService());

/// Stream of all articles sorted by recency.
final timelineProvider = StreamProvider<List<Article>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.articles)
        ..orderBy([(t) => drift.OrderingTerm.desc(t.pubDate)]))
      .watch();
});

/// Stream of all categories.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

/// Stream of articles sorted for the "Für Dich" feed using the algorithm:
/// `(Interest_in_category * 0.7) + (Recency * 0.3)`
/// where Recency is linearly reduced over 168 hours (7 days).
final forYouProvider = StreamProvider<List<Article>>((ref) async* {
  final db = ref.watch(databaseProvider);

  // We need to continuously emit when articles OR categories update
  final stream = db.select(db.articles).join([
    drift.leftOuterJoin(
        db.categories, db.categories.name.equalsExp(db.articles.category)),
  ]).watch();

  await for (final rows in stream) {
    final now = DateTime.now();

    final scoredArticles = rows.map((row) {
      final article = row.readTable(db.articles);
      final categoryWeight =
          row.readTableOrNull(db.categories)?.globalWeight ?? 0.0;

      final ageHours = now.difference(article.pubDate).inHours.toDouble();

      // Max 1.0, minimum 0.0, reduces over 168 hours (7 days)
      var recency = 1.0 - (ageHours / 168.0);
      if (recency < 0) recency = 0;
      if (recency > 1) recency = 1;

      final totalScore = (categoryWeight * 0.7) + (recency * 0.3);

      return (article: article, score: totalScore);
    }).toList();

    // Sort by computed score (DESC)
    scoredArticles.sort((a, b) => b.score.compareTo(a.score));

    // Return the sorted articles
    yield scoredArticles.map((e) => e.article).toList();
  }
});
