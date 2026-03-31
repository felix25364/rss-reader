import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import 'article_screen.dart';

class CategoryDetailScreen extends ConsumerWidget {
  final String categoryName;

  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncArticles = ref.watch(categoryArticlesProvider(categoryName));

    return Scaffold(
      appBar: AppBar(title: Text('Thema: $categoryName')),
      body: asyncArticles.when(
        data: (articles) {
          if (articles.isEmpty) {
            return const Center(child: Text('Keine Artikel in dieser Kategorie.'));
          }
          return ListView.separated(
            itemCount: articles.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final article = articles[index];
              return ListTile(
                leading: article.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        article.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.article),
                      ),
                    )
                  : const Icon(Icons.article),
                title: Text(article.title),
                subtitle: Text(
                  '${article.pubDate.day}.${article.pubDate.month}.${article.pubDate.year}',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArticleScreen(article: article),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Fehler: $err')),
      ),
    );
  }
}
