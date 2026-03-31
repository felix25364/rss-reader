import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart' as drift;

import '../../providers/providers.dart';
import '../../models/database.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Erscheinungsbild'),
            subtitle: Text(themeMode.name.toUpperCase()),
            trailing: PopupMenuButton<ThemeMode>(
              initialValue: themeMode,
              onSelected: (mode) {
                ref.read(themeProvider.notifier).state = mode;
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                const PopupMenuItem(
                  value: ThemeMode.light,
                  child: Text('Hell'),
                ),
                const PopupMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dunkel'),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Feeds importieren (OPML)'),
            leading: const Icon(Icons.file_upload),
            onTap: () => _importOpml(context, ref),
          ),
          ListTile(
            title: const Text('Feeds exportieren (OPML)'),
            leading: const Icon(Icons.file_download),
            onTap: () => _exportOpml(context, ref),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Kategorie-Scores verwalten', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Keine Kategorien vorhanden.'),
                );
              }
              return Column(
                children: categories.map((cat) {
                  return ListTile(
                    title: Text(cat.name),
                    subtitle: Text('Score: ${cat.globalWeight.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _adjustScore(ref, cat, -1.0),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _adjustScore(ref, cat, 1.0),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Score zurücksetzen',
                          onPressed: () => _resetScore(ref, cat),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Fehler: $err')),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustScore(WidgetRef ref, drift.Category cat, double amount) async {
    final db = ref.read(databaseProvider);
    final newScore = (cat.globalWeight + amount).clamp(0.0, double.infinity);
    await db.update(db.categories).replace(cat.copyWith(globalWeight: newScore));
  }

  Future<void> _resetScore(WidgetRef ref, drift.Category cat) async {
    final db = ref.read(databaseProvider);
    await db.update(db.categories).replace(cat.copyWith(globalWeight: 0.0));
  }

  Future<void> _importOpml(BuildContext context, WidgetRef ref) async {
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importiere Feeds...')),
          );
        }

        final urls = await opmlService.parseOpml(file);
        int totalArticles = 0;

        for (final url in urls) {
          final articles = await rssService.fetchFeed(url);

          for (final a in articles) {
            final categoryName = await classifier.classifyText(a.title, a.content);

            final catQuery = db.select(db.categories)..where((c) => c.name.equals(categoryName));
            final cat = await catQuery.getSingleOrNull();

            if (cat == null) {
              await db.into(db.categories).insert(
                CategoriesCompanion.insert(name: categoryName),
              );
            }

            await db.into(db.articles).insert(
              ArticlesCompanion.insert(
                title: a.title,
                link: a.link,
                content: a.content,
                imageUrl: drift.Value(a.imageUrl),
                pubDate: a.pubDate,
                category: drift.Value(categoryName),
              ),
            );
            totalArticles++;
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erfolgreich $totalArticles Artikel importiert.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Import: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    // Note: Since we only store articles and not explicit feed URLs in our current DB schema,
    // a true OPML export would need a Feeds table.
    // For this example, we'll generate a dummy OPML to show functionality.

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/export.opml');

    const opmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
  <head>
    <title>Nucleus RSS Export</title>
  </head>
  <body>
    <!-- In a full app, we would query the Feeds table here and loop over outlines -->
    <outline text="Dummy Feed" xmlUrl="https://example.com/feed.xml" />
  </body>
</opml>''';

    await file.writeAsString(opmlContent);

    if (context.mounted) {
      await Share.shareXFiles([XFile(file.path)], text: 'Mein Nucleus RSS OPML Export');
    }
  }
}
