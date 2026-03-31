import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import 'category_view.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../services/opml_service.dart';
import '../../services/rss_service.dart';
import '../../services/classifier_service.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

/// Main scaffold with NavigationBar for the Pixel 8.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initClassifier();
  }

  Future<void> _initClassifier() async {
    // Show dialog on first run to download language model
    final classifier = ref.read(classifierServiceProvider);

    // Simplification for the example: just download German/English immediately if not present.
    // In a full production app, you might show a settings dialog before calling this.
    try {
      await classifier.initialize(EntityExtractorLanguage.german);
      await classifier.initialize(EntityExtractorLanguage.english);
    } catch (e) {
      debugPrint("ML Kit error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nucleus RSS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importOpml,
            tooltip: 'OPML Importieren',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildFeedView(timelineProvider),
          _buildFeedView(forYouProvider),
          const CategoryViewScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timeline),
            label: 'Zeitachse',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Für Dich',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Themen',
          ),
        ],
      ),
    );
  }

  Widget _buildFeedView(StreamProvider<List<dynamic>> provider) {
    final streamAsync = ref.watch(provider);

    return streamAsync.when(
      data: (articles) {
        if (articles.isEmpty) {
          return const Center(child: Text('Keine Artikel gefunden.'));
        }

        return ListView.separated(
          itemCount: articles.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final article = articles[index];
            return ListTile(
              title: Text(article.title),
              subtitle: Text(
                '${article.category ?? 'Unkategorisiert'} • ${article.pubDate.day}.${article.pubDate.month}.${article.pubDate.year}',
              ),
              onTap: () async {
                // Increase user interest score for the category globally
                if (article.category != null) {
                  final db = ref.read(databaseProvider);
                  final catQuery = db.select(db.categories)..where((c) => c.name.equals(article.category!));
                  final cat = await catQuery.getSingleOrNull();
                  if (cat != null) {
                    await db.update(db.categories).replace(
                      cat.copyWith(globalWeight: cat.globalWeight + 1.0),
                    );
                  }
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Fehler: $err')),
    );
  }

  Future<void> _importOpml() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['opml', 'xml'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final opmlService = ref.read(opmlServiceProvider);
      final rssService = ref.read(rssServiceProvider);
      final classifier = ref.read(classifierServiceProvider);
      final db = ref.read(databaseProvider);

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importiere Feeds...')),
        );

        final urls = await opmlService.parseOpml(file);
        int totalArticles = 0;

        for (final url in urls) {
          final articles = await rssService.fetchFeed(url);

          for (final a in articles) {
            // Classify content using background isolate
            final categoryName = await classifier.classifyText(a.title, a.content);

            // Ensure category exists
            final catQuery = db.select(db.categories)..where((c) => c.name.equals(categoryName));
            final cat = await catQuery.getSingleOrNull();

            if (cat == null) {
              await db.into(db.categories).insert(
                CategoriesCompanion.insert(name: categoryName),
              );
            }

            // Insert article
            await db.into(db.articles).insert(
              ArticlesCompanion.insert(
                title: a.title,
                link: a.link,
                content: a.content,
                pubDate: a.pubDate,
                category: drift.Value(categoryName),
              ),
            );
            totalArticles++;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erfolgreich $totalArticles Artikel importiert.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Import: $e')),
          );
        }
      }
    }
  }
}
